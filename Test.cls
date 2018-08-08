Class DocumentTemplate.Test
{

/// Load all test documents in the database from the <var>directory</var>
ClassMethod LoadTestDocs(directory)
{
	set namesList = $LB("SimpleTextSubstitution.docx",
						"ExpressionSubstitution.docx"
	)
	set ptr=0
	while $listnext(namesList, ptr, name){
		set documentFile = ##class(%File).NormalizeFilename(name, directory) 
		set error = ##class(DocumentTemplate.DocumentTemplate).LoadDocument(documentFile, name, "test")
		if error'=""{
			write !,"Error while loading test document "_documentFile_": ",!,"	"_error
		} 
		else{
			write !,"Test document "_documentFile_" is loaded"
		}
	}
}

ClassMethod RunAllTests()
{
	set namesList = $LB("SimpleTextSubstitution",
						"ExpressionSubstitution"
	)
	set ptr=0
	while $listnext(namesList, ptr, name){
		set error = $classmethod("DocumentTemplate.Test", "Test"_name)
		if error'=""{
			write !, "Error while rendering template "_name
			write !,error
		}
		else {
			write !, "Template "_name_" is rendered successfully"
		}
	}
}

ClassMethod TestSimpleTextSubstitution() [ ProcedureBlock = 0 ]
{
	set header = "Somehting on the top"
	set footer1 = "I'm in the left bottom"
	set footer2 = "I'm in the middle"
	set footer3 = "I'm in the right corner"
	set title = "Simple example of text substitution"
	set a = "center of the page"
	set b = "String width are matter"
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("SimpleTextSubstitution.docx")
	quit error
}

ClassMethod TestExpressionSubstitution() [ ProcedureBlock = 0 ]
{
	set a = "First part"
	set b = "and second part" 
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("ExpressionSubstitution.docx")
	quit error
}

ClassMethod TestOrderLoopParagraph()
{
}

ClassMethod TestOrderTableRows()
{
}

ClassMethod TestOrderTableColumns()
{
}

ClassMethod TestOrderTableRowsAndColumns()
{
}

ClassMethod TestIfParagraph()
{
}

ClassMethod TestIfRows()
{
}

ClassMethod TestNestedOrder()
{
}

ClassMethod TestNestedOrderIf()
{
}

}
