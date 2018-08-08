Include %sySystem

/// Класс <CLASS>DocumentPatterns</CLASS> представляет собой шаблон документа Word или Excel
/// <p>^DocumentTemplateSettings - глобал для хранения настроек фукционала шаблонов документов</p>
/// <p>^DocumentTemplateSettings("workingDirectory") - рабочая директория для экспорта, импорта файлов. По умолчанию install-dir\mgr\Temp</p>
/// <p>^DocumentTemplateSettings("zipCommand") - команда для создания zip архива(принимает имя файла, директорию)</p>
/// <p>^DocumentTemplateSettings("unzipCommand") - команда для распаковки zip архива(принимает имя файла, директорию)</p>
/// <p> Команды упаковки, распаковки должны содержать слова $Fullfilename и $Directory для замены</p>
/// <p> При запаковке команда запаковки выполняется относительно директории распакованного документа </p>
/// <p> Пример для windows 7z </p>
/// <p> ^DocumentTemplateSettings("zipCommand")="""C:\Program Files\7-Zip\7z.exe"" a -y $Fullfilename $Directory\*"</p>
/// <p> ^DocumentTemplateSettings("unzipCommand")="""C:\Program Files\7-Zip\7z.exe"" x -y -o$Directory $Fullfilename"</p>
/// <p> пример для линукса zip unzip</p>
/// <p> unzip -u -q -d $Directory  $Fullfilename </p>
/// <p> zip -r -u -q $Fullfilename ./*</p>
/// <p>^DocumentTemplateSettings("maxOrderIterations") - для защиты от бесконечных циклов, максимальное количество допустипух итераций в цикле
Class DocumentTemplate.DocumentTemplate Extends %Persistent
{

/// Сам документ docx или xlsx
Property Content As %Stream.GlobalBinary [ Required ];

/// Группа шаблона документа
Property Group As %String;

/// Имя документа
Property Filename As %String;

/// Описание документа
Property Description As %String(MAXLEN = 512);

/// Дата, время загрузки
Property DateTime As %DateTime [ Required ];

Index Name On Filename [ Unique ];

/// Получить документ по именни файла и группы
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

/// Загрузка файла в таблицу с шаблонами
/// <var>fullFulename</var> - полный путь к фалу
/// <var>group</var> - группа шаблона
ClassMethod LoadDocument(fullFilename As %String, name As %String, group As %String = "default", description As %String = "") As %String
{
	// поток для чтения документа
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

/// Загрузка документа из глобала
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

/// Функция создания документа на основе шаблона
/// <var>masRef</var> - ссылка на массив для сгенерированного документа
/// <var>deleteFile</var> - удалять ли файл в рабочей директории после сохранения в глобал
ClassMethod RenderDocument(name As %String, masRef As %String = "^||RenderedDocument", deleteFile As %Boolean = 0) As %String
{
	if masRef'["^||" quit "masRef - должен быть private global"
	k @masRef
	set documentTemplate = ##class(DocumentTemplate.DocumentTemplate).GetDocument(name)
	if documentTemplate="" quit "Темплейт с именем "_name_" не найден"
	
	set workingDirectory = $Get(^DocumentTemplateSettings("workingDirectory"),$Get(^%SYS("TempDir")))
	
	if workingDirectory=""{
		quit "Не задана рабочая директрия ^DocumentTemplateSettings(""workingDirectory"")"
	}
	set created = ##class(%File).CreateDirectoryChain(workingDirectory)
	if created'=1{
		quit "Ошибка при создании рабочей директории"
	}
	d ..WriteDebug("Рабочая директория существует")
	//Копирование шаблона документа в рабочую директорию если его еще нет
	set filename = $Replace($ZDTH(documentTemplate.DateTime,3,3),",","-")_"-"_documentTemplate.Filename
	set fullFileName = ##class(%File).NormalizeFilename(filename, workingDirectory)
	if '##class(%File).Exists(fullFileName){
		set sc = documentTemplate.CopyOnDisk(workingDirectory, filename)
		if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	}
	
	// Имя директории для распаковки: датавремя_распаковки_шаблона-$J-имяфайла
	set unpackDirectory = $Replace($H,",","-")_"-"_$J_"-"_$Replace(documentTemplate.Filename,".","-")
	set fullUnpackDirectory = ##class(%File).NormalizeFilename(unpackDirectory, workingDirectory)
	
	set sc = ..Unpack(fullFileName, fullUnpackDirectory)
	if sc'="" d ..WriteDebug(sc) quit sc
	d ..WriteDebug("Документ распакован")
	set error = ##class(DocumentTemplate.DocXmlRenderer).%New(fullUnpackDirectory).Render()
	if error'="" d ..WriteDebug("Ошибка при обработке шаблона "_error) quit error

	// Запаковка сгенерированного документа
	set renderedFilename = $Replace($H,",","-")_"-"_$J_"-"_documentTemplate.Filename
	set fullRenderedFilename = ##class(%File).NormalizeFilename(renderedFilename, workingDirectory)
	set sc = ..Pack(fullUnpackDirectory, fullRenderedFilename)
	if $$$ISERR(sc) do clean quit $system.OBJ.DisplayError(sc) 
	// Копирование документа в массив
	set stream=##class(%Stream.FileBinary).%New()
	set sc=stream.LinkToFile(fullRenderedFilename)
	if $$$ISERR(sc) do clean quit $system.OBJ.DisplayError(sc) 
	set streamTo = ##class(%Stream.GlobalBinary).%New(masRef)
	set sc = streamTo.CopyFromAndSave(stream)
	if $$$ISERR(sc) do clean quit $system.OBJ.DisplayError(sc) 
	do clean
	quit ""
clean
	// Удаление распакованной директории
	do ##class(%File).RemoveDirectoryTree(fullUnpackDirectory)
	d ..WriteDebug("Удаление директории "_fullUnpackDirectory)
	// Удаление документа 
	if deleteFile=1{
		d ##class(%File).ComplexDelete(fullRenderedFilename)
		d ..WriteDebug("Удаление файла "_fullRenderedFilename)
	}
	quit
}

/// Распаковка документа на диске в директорию
ClassMethod Unpack(fullFilename As %String, directory As %String) As %String
{
	set zipCommand = ..GetUnzipCommand(fullFilename, directory)
	if zipCommand=""{
		quit "Не задана команда распаковки архива ^DocumentTemplateSettings(""unzipCommand"")"
	}
	
	set created = ##class(%File).CreateDirectoryChain(directory)
	if 'created{
		quit "Ошибка создания директории для распаковки шаблона "
	}
	// Сохранение текущей директории
	set curDir = ##class(%SYSTEM.Process).CurrentDirectory()
	do ##class(%SYSTEM.Process).CurrentDirectory(directory)
	set sc = $ZF(-1, zipCommand)
	if sc'=0{
		d ##class(%SYSTEM.Process).CurrentDirectory(curDir)
		quit "Ошибка при распаковке"
	}
	// Восстановление текущей директории 
	d ##class(%SYSTEM.Process).CurrentDirectory(curDir)
	
	quit ""
}

/// Упаковка документа 
ClassMethod Pack(directory As %String, fullFilename As %String) As %Status
{
	set zipCommand = ..GetZipCommand(fullFilename, directory)
	if zipCommand=""{
		quit $$$ERROR($$$GeneralError,"Не задана команда распаковки архива ^DocumentTemplateSettings(""unzipCommand"")")
	}
	
	set exists = ##class(%File).Exists(directory)
	if 'exists{
		quit $$$ERROR($$$GeneralError, "Директория не существует ")
	}
	// Сохранение текущей директории
	set curDir = ##class(%SYSTEM.Process).CurrentDirectory()
	do ##class(%SYSTEM.Process).CurrentDirectory(directory)
	set sc = $ZF(-1, zipCommand)
	if sc'=0{
		d ##class(%SYSTEM.Process).CurrentDirectory(curDir)
		quit $$$ERROR($$$GeneralError, "Ошибка при упаковке документа")
	}
	// Восстановление текущей директории 
	d ##class(%SYSTEM.Process).CurrentDirectory(curDir)
	quit $$$OK
}

/// Метод берет ^DocumentTemplateSettings("zipCommand") и вставляет параметры
/// Возвращает команду упаковки файлов из директории <var>directory</var> в файл <var>fullFilename</var>
ClassMethod GetZipCommand(fullFilename, directory)
{
	set zipCommand = $Replace($Get(^DocumentTemplateSettings("zipCommand")), "$Directory", directory)
	set zipCommand = $Replace(zipCommand, "$Fullfilename", fullFilename)
	quit zipCommand
}

/// Метод берет ^DocumentTemplateSettings("unzipCommand") и вставляет параметры
/// Возвращает команду распаковки файлов из файла <var>fullFilename</var> в директорию <var>directory</var> в 
ClassMethod GetUnzipCommand(fullFilename, directory)
{
	set zipCommand = $Replace($Get(^DocumentTemplateSettings("unzipCommand")), "$Directory", directory)
	set zipCommand = $Replace(zipCommand, "$Fullfilename", fullFilename)
	quit zipCommand
}

/// Копирование документа из базы на диск
/// <var>directory</var> - директория куда выполнить копирование
/// <var>filename</var> - имя файла 
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
	write !,string
	//set counter = $O(^DocumentPatternLog($J,$H,""),-1)
	//set ^DocumentPatternLog($J,$H,counter + 1,string)=""
}

}
