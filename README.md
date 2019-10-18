# DocumentTemplate

DocumentTemplate allows you to use Open Document Text (ODT) and Microsoft Word (docx) files as templates for rendering reports or letters.
Templates can be visually composed in LibreOffice or Microsoft Word
It use special semantics to render files. 


## Installing 

1. Import DocumentTemplate.xml. 

2. Set up command for zip and unzip  in ```^DocumentTemplateSettings("zipCommand")``` and ```^DocumentTemplateSettings("unzipCommand")``` respectively. Command must contain ```$Directory``` and ```$Fullfilename``` strings. Program will replace them with actual directory and archive filename.
For example, on Linux you can use zip and unzip:
```
set ^DocumentTemplateSettings("zipCommand")="zip -r -u -q $Fullfilename ./*"
set ^DocumentTemplateSettings("unzipCommand")="unzip -u -q -d $Directory  $Fullfilename "
``` 
On Windows 7-zip:
```
set ^DocumentTemplateSettings("zipCommand")="""C:\Program Files\7-Zip\7z.exe"" a -y $Fullfilename $Directory\*"
set ^DocumentTemplateSettings("unzipCommand")="""C:\Program Files\7-Zip\7z.exe"" x -y -o$Directory $Fullfilename"
```
3. Set up working directory in ^DocumentTemplateSettings("workingDirectory"), where template documents will be unpacked for rendering. By default the directory ^%SYS("TempDir") will be used.

4. Run tests to ensure everything works fine:
```
do ##class(DocumentsTemplates.Test).RunAllTests("<path-to-project-dir>\TestDocs")
```
Rendered test documents you will find in working directory.
	   
## Rendering a template
1. Create a template in Libre or Microsoft Word.
2. Write Method or procedure, which declare all variables in template. Method must be declared with [ProcedureBlock = 0] keyword.
3. In method use the command  to render document:
    ```
    set error =  ##class(DocumentTemplate.DocumentTemplate).RenderDocumentFromTemplate("<full-path-to-your-template>","<full-path-to-your-rendered-document>")
    ```
if error=""  than no errors occured.

DocumentTemplate class allows you to store templates in database. 
Load template in database:
```
do ##class(DocumentTemplate.DocumentTemplate).LoadDocument("<full-path-to-your-template>", "nameOfTemplate1.docx")
```
To render loaded template:
```
set error =  ##class(DocumentTemplate.DocumentTemplate).RenderDocument("nameOfTemplate1.docx","<full-path-to-your-rendered-document>")
```
### Example
```
ClassMethod TestSimpleTextSubstitution() [ ProcedureBlock = 0 ]
{
	set header = "Somehting on the top"
	set footer1 = "I'm in the left bottom"
	set footer2 = "I'm in the middle"
	set footer3 = "I'm in the right corner"
	set title = "Simple example of text substitution"
	set a = "center of the page"
	set b = "String width are matter"

	set error =  ##class(DocumentTemplate.DocumentTemplate).RenderDocumentFromTemplate("/tmp/SimpleTextSubstitution.odt", "/tmp/renderedDocument.odt")
}
```

## Composing Templates
Templates are simple ODT  or DOCX documents. You can create them using LibreOffice or Microsoft Word. 
**The style of rendered part will be the same style as style of first curly brace in tag.**
	
### Printing variables and expressions
	
	To print a varible or expression  type a double curly braces enclosing the variable:
		
		{{variableName}}
		
	
### Iteration over subscripted variable
	
	DocumentTemplate can repeat parts of the template (rows of table, paragraphs, simple words) using subscripted variables. Example of using order tag:
	
		{% order array index %}
			Index is {{index}}. Arrya(index) = {{ array(index) }}
		{% endorder %}

	The programm will create 'index' variable for iteration. 'array' must be declared in your function. 
	For more examples see: 
		- TestDocs\ListAndTable.odt
		- TestDocs\OrderTableRows.odt
		- TestDocs\OrderTableRows.odt
		- TestDocs\NestedOrder.odt
	
### if block

	The {% if %} tag evaluates expression, and if that expression is “true”  the contents of the block are output:
	
		{% if a=0 %}
			If variable a equals to ziro. You wll never see this string.
		{% endif %}

	Examples of using if tag:
		- TestDocs\IfParagraph.odt
		- TestDocs\IfRows.odt
		- TestDocs\NestedOrderIf.odt
		
### Declaring variable inside the template

	You can declare a variable in your template using {% set %} tag: 
		{% set rowCounter=0 %}

	Examples of using set tag:
		- TestDocs\RowCounter.odt
		- TestDocs\ThreeDigits.odt
		

		
## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details
