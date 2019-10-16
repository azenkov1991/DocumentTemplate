Class DocumentTemplate.Test
{

/// Load all test documents in the database from the <var>directory</var>
ClassMethod LoadTestDocs(directory)
{
	set namesList = ..GetTestNames()
	set ptr=0
	while $listnext(namesList, ptr, name){
		for extension = "docx","odt"{
			set fileName = name_"."_extension
			set existingDocument = ##class(DocumentTemplate.DocumentTemplate).GetDocument(fileName)
			if existingDocument{
				d ##class(DocumentTemplate.DocumentTemplate).%DeleteId(existingDocument.%Id())
			}
			set documentFile = ##class(%File).NormalizeFilename(fileName, directory) 
			set error = ##class(DocumentTemplate.DocumentTemplate).LoadDocument(documentFile, fileName, "test")
			if error'=""{
				write !,"Error while loading test document "_documentFile_": ",!,"	"_error
			} 
			else{
				write !,"Test document "_documentFile_" is loaded"
			}
		}
	}
}

ClassMethod RunAllTests(directory = "", extension = "")
{
	set namesList = ..GetTestNames()
	set ptr=0
	while $listnext(namesList, ptr, name){
		do ..RunTest(name, directory, extension)
	}
}

ClassMethod GetTestNames()
{
	quit $LB("SimpleTextSubstitution",
			 "ExpressionSubstitution",
			 "IfParagraph",
			 "IfRows",
			 "OrderTableRows",
			 "OrderTableRowsAndColumns",
			 "OrderParagraph",
			 "OrderTableColumns",
			 "NestedOrder",
			 "NestedOrderIf",
			 "HeadersAndFooters",
			 "RowCounter",
			 "ListAndTable",
			 "ThreeDigits",
			 "SamplePersonsTable"
	)
}

ClassMethod RunTest(testName, directory = "", extension = "") [ ProcedureBlock = 0 ]
{
	try{
	//create context for test
	do $classmethod("DocumentTemplate.Test", "Test"_testName)
	
	if extension=""{
		set extensionList=$LB("docx","odt")
	}
	else{
		set extensionList=$LB(extension)
	}
	set ptr=0
	while $listnext(extensionList, ptr, extension){
		set templateFilename = testName_"."_extension
		if directory'=""{
			set templateFullFilename = ##class(%File).NormalizeFilename(templateFilename, directory)
			set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocumentFromTemplate(templateFullFilename)
		}
		else{
			set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument(templateFilename)
		}
		if error'=""{
			write !, "Error while rendering template "_testName
			write !,error
		}
		else {
			write !, "Template "_testName_" is rendered successfully"
		}
	}
	}
	catch error{
		write !, "Error while rendering template "_testName
		write !, error.Name_" "_error.Location
	}
}

ClassMethod GetTestStrings(ByRef var)
{
	
	kill var
	set var(1) = "Appear weak when you are strong, and strong when you are weak"
	set var(2) = "The supreme art of war is to subdue the enemy without fighting"
	set var(3) = "If you know the enemy and know yourself, you need not fear the result of a hundred battles. If you know yourself but not the enemy, for every victory gained you will also suffer a defeat. If you know neither the enemy nor yourself, you will succumb in every battle."
	set var(4) = "Let your plans be dark and impenetrable as night, and when you move, fall like a thunderbolt."
	set var(5) = "Supreme excellence consists of breaking the enemy's resistance without fighting."  
	set var(6) = "All warfare is based on deception. Hence, when we are able to attack, we must seem unable; when using our forces, we must appear inactive; when we are near, we must make the enemy believe we are far away; when far away, we must make him believe we are near."
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
}

ClassMethod TestExpressionSubstitution() [ ProcedureBlock = 0 ]
{
	set a = "First part"
	set b = "and second part"
}

ClassMethod TestOrderParagraph() [ ProcedureBlock = 0 ]
{
	do ..GetTestStrings(.paragraph)
}

ClassMethod TestOrderTableRows() [ ProcedureBlock = 0 ]
{
	for i=1:1:15{
		set firstColumn(i)="firsRow "_i
	}
	for j=1:1:10{
		set secondColumn(j)="secondRow"_j
	}
}

ClassMethod TestOrderTableColumns() [ ProcedureBlock = 0 ]
{
	kill row1, row1, row3
	for i=1:1:3{
		set row1(i) = "row1 "_i
	}
	for i=1:1:3{
		set row2(i) = "row2 "_i
	}
	for i=1:1:3{
		set row3(i) = "row3 "_i
	}
}

ClassMethod TestOrderTableRowsAndColumns() [ ProcedureBlock = 0 ]
{
	kill table
	for i=1:1:10{
		for j=1:1:5{
			set table(i,j)="r "_i_"c "_j
		}
	}
}

ClassMethod TestIfParagraph() [ ProcedureBlock = 0 ]
{
}

ClassMethod TestIfRows() [ ProcedureBlock = 0 ]
{
	kill row
	for i=1:1:4{
		if i#2{
			set row(i) = "visible row"
		}
		else{
			set row(i) = "invisible row"
		}
	}
}

ClassMethod TestNestedOrder() [ ProcedureBlock = 0 ]
{
	for i=1:1:13{
		for j=1:1:120{
			if j=1{
				set paragraphs(i,j) = "Word "_i_" "_j
			}
			else{
				if j#7=1{
					set paragraphs(i,j) = ". Word "_i_" "_j
				}
				else{
					set paragraphs(i,j) = "word "_i_" "_j
				}
			}
			
		}
	}
}

ClassMethod TestNestedOrderIf() [ ProcedureBlock = 0 ]
{
	kill paragraphs
	for i=1:1:13{
		for j=1:1:11{
			set paragraphs(i,j) = "word "_i_" "_j
		}
	}
}

ClassMethod TestHeadersAndFooters() [ ProcedureBlock = 0 ]
{
	set top1 = "First page"
	set bottom = "End of the first page"
	set top2 = "Second page"
	set bottom2 = "End of the second page"
	set topLeft = "Left corner"
	set topMiddle = "I'm in the middle"
	set topRight = "Right corner"
	set top4 = "top3 is missing"
	set bottom4 = "End of the document"
}

ClassMethod TestRowCounter() [ ProcedureBlock = 0 ]
{
	do ..GetTestStrings(.rows)
}

ClassMethod TestListAndTable() [ ProcedureBlock = 0 ]
{
	do ..GetTestStrings(.row)
	set header = "Example of generating document"
}

ClassMethod TestThreeDigits()
{
}

ClassMethod TestSamplePersonsTable()
{
}

}
