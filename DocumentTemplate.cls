Include %sySystem

/// Class <CLASS>DocumentPatterns</CLASS> represents a template of docs or odt document
/// <p>^DocumentTemplateSettings - global for settgins </p>
/// <p>^DocumentTemplateSettings("workingDirectory") - working directory for export/import files. By default: install-dir\mgr\Temp</p>
/// <p>^DocumentTemplateSettings("zipCommand") - system command for making zip archive (take filename and directory)</p>
/// <p>^DocumentTemplateSettings("unzipCommand") - system command for unzipping (take filename and directory)</p>
/// <p> Zip/unzip commands must contain words $Fullfilename and $Directory for replacing with actual filename and directory name </p>
/// <p> zip command is executed in directory of unpacked document </p>
/// <p> Example for windows 7z </p>
/// <p> ^DocumentTemplateSettings("zipCommand")="""C:\Program Files\7-Zip\7z.exe"" a -y $Fullfilename $Directory\*"</p>
/// <p> ^DocumentTemplateSettings("unzipCommand")="""C:\Program Files\7-Zip\7z.exe"" x -y -o$Directory $Fullfilename"</p>
/// <p> Example for linux zip unzip</p>
/// <p> unzip -u -q -d $Directory  $Fullfilename </p>
/// <p> zip -r -u -q $Fullfilename ./*</p>
/// <p>^DocumentTemplateSettings("maxOrderIterations") - for protection against infinite loops, maximum iterations in order loop. 128000 by default
Class DocumentTemplate.DocumentTemplate Extends %Persistent
{

/// Document binary content 
Property Content As %Stream.GlobalBinary [ Required ];

/// Group of templates
Property Group As %String;

/// Filename
Property Filename As %String;

/// Document description
Property Description As %String(MAXLEN = 512);

/// Datetime of loading
Property DateTime As %DateTime [ Required ];

Index Name On Filename [ Unique ];

/// Get document by name and group name
ClassMethod GetDocument(name As %String) As DocumentTemplate.DocumentTemplate
{
	set doc = ##class(DocumentTemplate.DocumentTemplate).NameOpen(name, 2, .sc)
	if $$$ISOK(sc){
		quit doc
	}
	else{
		quit ""
	}
}

/// Load template in database
/// <var>fullFulename</var> - full filename of the document
/// <var>name</var> - name of template in database
/// <var>group</var> - group of template
ClassMethod LoadDocument(fullFilename As %String, name As %String, group As %String = "default", description As %String = "") As %String
{
	set stream=##class(%Stream.FileBinary).%New()
	set newDocument=##class(DocumentTemplate.DocumentTemplate).%New()
	set sc=stream.LinkToFile(fullFilename)
	if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	set newDocument.Group = group
	set newDocument.Description = $G(description)
	set newDocument.Filename = name
	set newDocument.DateTime = $ZDT($H,3,3)
	set sc = newDocument.Content.CopyFromAndSave(stream)
	if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	set sc = newDocument.%Save()
	if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	quit ""
}

/// Load document from global
ClassMethod LoadDocumentFromGlobal(masRef, name, group As %String = "default") As %String
{
	set newDocument=##class(DocumentTemplate.DocumentTemplate).%New()
	set newDocument.Group = group
	set newDocument.Filename = name
	set newDocument.DateTime = $ZDT($H,3,3)
	set streamFrom = ##class(%Stream.GlobalBinary).%New()
	set streamFrom.%Location = masRef
	set sc = newDocument.Content.CopyFromAndSave(streamFrom)
	if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	set sc = newDocument.%Save()
	if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	quit ""
}

/// Render document template to  private global
/// <var>templateName</var>
/// <var>masRef</var> - global reference 
/// <var>deleteFile</var> - remove rendered document in working directory 
ClassMethod RenderDocumentToPrivateGlobal(templateName As %String, masRef As %String = "^||RenderedDocument", deleteFile As %Boolean = 0)
{
	if masRef'["^||" quit "masRef - must be private global reference"
	k @masRef	
	
	set renderedFilename = $Replace($H,",","-")_"-"_$J_"-"_documentTemplate.Filename
	set fullRenderedFilename = ##class(%File).NormalizeFilename(renderedFilename, workingDirectory)
	
	set error = ..RenderDocument(templateName, fullRenderedFilename)
	if error '="" quit error
	
	// Copy document to global
	set stream=##class(%Stream.FileBinary).%New()
	set sc=stream.LinkToFile(fullRenderedFilename)
	if $$$ISERR(sc)  quit $system.OBJ.DisplayError(sc) 
	set streamTo = ##class(%Stream.GlobalBinary).%New(masRef)
	set sc = streamTo.CopyFromAndSave(stream)
	if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc) 
	
	// Delete document 
	if deleteFile=1{
		d ##class(%File).ComplexDelete(fullRenderedFilename)
		d ..WriteDebug("Delete file "_fullRenderedFilename)
	}
	quit ""
}

/// Render document template
/// <var>templateName</var>
/// <var>renderedDocumentFullFilename</var> - full filename of rendered document. If not given than document will created in working directory
ClassMethod RenderDocument(templateName As %String, renderedDocumentFullFilename As %String = "") As %String
{
	
	set documentTemplate = ##class(DocumentTemplate.DocumentTemplate).GetDocument(templateName)
	if documentTemplate="" quit "Template with name  "_templateName_" not found"
	
	set workingDirectory = ..GetWorkingDirectory()
	
	if workingDirectory=""{
		quit "The working directory is not set. s ^DocumentTemplateSettings(""workingDirectory"")=""your working directory"""
	}
	set created = ##class(%File).CreateDirectoryChain(workingDirectory)
	if created'=1{
		quit "Can't create working directory"
	}
	d ..WriteDebug("Working directory exists")
	
	//Copy template in working directory if it doesn't exist
	set templateFilename = $Replace($ZDTH(documentTemplate.DateTime,3,3),",","-")_"-"_documentTemplate.Filename
	
	
	set templateFullFilename = ##class(%File).NormalizeFilename(templateFilename, workingDirectory)
	if '##class(%File).Exists(templateFullFilename){
		set sc = documentTemplate.CopyOnDisk(workingDirectory, templateFilename)
		if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	}
	
	quit ..RenderDocumentFromTemplate(templateFullFilename, renderedDocumentFullFilename)
}

/// Render document from template which is was not loaded to database
/// <var>fullFilenameTemplate</var> full path to the template
/// <var>renderedFilename</var> - fullname of result document
ClassMethod RenderDocumentFromTemplate(templateFullFilename, renderedDocumentFullFilename)
{
	set workingDirectory = ..GetWorkingDirectory()
	
	if workingDirectory=""{
		quit "The working directory is not set. s ^DocumentTemplateSettings(""workingDirectory"")=""your working directory"""
	}
	set created = ##class(%File).CreateDirectoryChain(workingDirectory)
	if created'=1{
		quit "Can't create working directory"
	}
	d ..WriteDebug("Working directory exists")
	
	// Directory name for unpacking: unpackin_datetime-$J-templatename
	set templateFilename = ##class(%File).GetFilename(templateFullFilename)
	set unpackDirectory = $Replace(templateFilename,".","-")
	set fullUnpackDirectory = ##class(%File).NormalizeFilename(unpackDirectory, workingDirectory)
	
	set sc = ..Unpack(templateFullFilename, fullUnpackDirectory)
	if sc'="" d ..WriteDebug(sc) quit sc
	d ..WriteDebug("Template unpacked")
	set error = ##class(DocumentTemplate.DocXmlRenderer).%New(fullUnpackDirectory).Render()
	if error'="" d ..WriteDebug("Error while template processing "_error) quit error

	if $G(renderedDocumentFullFilename)="" {
		set renderedDocumentFullFilename = ##class(%File).NormalizeFilename($Replace($H,",","-")_"-"_$J_"-"_templateFilename, workingDirectory)
	}
	
	set sc = ..Pack(fullUnpackDirectory, renderedDocumentFullFilename)
	if $$$ISERR(sc) do clean quit $system.OBJ.DisplayError(sc) 
	
	do clean

	quit ""
clean
	// Delete directory of unpacked template
	do ##class(%File).RemoveDirectoryTree(fullUnpackDirectory)
	d ..WriteDebug("Remove directory "_fullUnpackDirectory)

	quit
}

ClassMethod GetWorkingDirectory()
{
	quit $Get(^DocumentTemplateSettings("workingDirectory"),$Get(^%SYS("TempDir")))
}

/// Unpack document in directory 
ClassMethod Unpack(fullFilename As %String, directory As %String) As %String
{
	set zipCommand = ..GetUnzipCommand(fullFilename, directory)
	if zipCommand=""{
		quit "Command for unzip is not set: set ^DocumentTemplateSettings(""unzipCommand"")=""your command"""
	}
	
	set created = ##class(%File).CreateDirectoryChain(directory)
	if 'created{
		quit "Error while creating directory for unpacking template "
	}
	// Save current directory
	set curDir = ##class(%SYSTEM.Process).CurrentDirectory()
	do ##class(%SYSTEM.Process).CurrentDirectory(directory)
	set sc = $ZF(-1, zipCommand)
	if sc>1{
		d ##class(%SYSTEM.Process).CurrentDirectory(curDir)
		quit "Error while unpacking. Command: "_zipCommand_" returned "_sc
	}
	// Restore current directory
	d ##class(%SYSTEM.Process).CurrentDirectory(curDir)
	
	quit ""
}

/// Pack document
ClassMethod Pack(directory As %String, fullFilename As %String) As %Status
{
	set zipCommand = ..GetZipCommand(fullFilename, directory)
	if zipCommand=""{
		quit "Command for zip is not set: set ^DocumentTemplateSettings(""zipCommand"")=""your command"""
	}
	
	set exists = ##class(%File).Exists(directory)
	if 'exists{
		quit "Error directory doesn't exist "
	}
	// Save current directory
	set curDir = ##class(%SYSTEM.Process).CurrentDirectory()
	do ##class(%SYSTEM.Process).CurrentDirectory(directory)
	set sc = $ZF(-1, zipCommand)
	if sc>1{
		d ##class(%SYSTEM.Process).CurrentDirectory(curDir)
		quit "Error while packing. Command: "_zipCommand_" returned "_sc
	}
	// Restore current directory 
	d ##class(%SYSTEM.Process).CurrentDirectory(curDir)
	quit $$$OK
}

/// Method takes ^DocumentTemplateSettings("zipCommand") and insert fullfilename and directory
/// Return  command for pack <var>directory</var> in file <var>fullFilename</var>
ClassMethod GetZipCommand(fullFilename, directory)
{
	set zipCommand = $Replace($Get(^DocumentTemplateSettings("zipCommand")), "$Directory", directory)
	set zipCommand = $Replace(zipCommand, "$Fullfilename", fullFilename)
	quit zipCommand
}

/// Method takes ^DocumentTemplateSettings("unzipCommand") and insert fullfilename and directory
/// Return command for unpack file <var>fullFilename</var> in directory <var>directory</var> 
ClassMethod GetUnzipCommand(fullFilename, directory)
{
	set zipCommand = $Replace($Get(^DocumentTemplateSettings("unzipCommand")), "$Directory", directory)
	set zipCommand = $Replace(zipCommand, "$Fullfilename", fullFilename)
	quit zipCommand
}

/// Copy template from database in directory
/// <var>directory</var> 
/// <var>filename</var>
Method CopyOnDisk(directory As %String, filename As %String = "") As %Status
{
	if filename="" set filename = ..Filename
	set fullFilename = ##class(%File).NormalizeFilename(filename, directory)
	set stream=##class(%Stream.FileBinary).%New()
	set sc=stream.LinkToFile(fullFilename)
	if $$$ISERR(sc) quit sc
	set sc = stream.CopyFromAndSave(..Content)
	if $$$ISERR(sc) quit sc
	quit $$$OK
}

ClassMethod WriteDebug(string)
{
	//write !,string
	//set counter = $O(^DocumentPatternLog($J,$H,""),-1)
	//set ^DocumentPatternLog($J,$H,counter + 1,string)=""
}

}
