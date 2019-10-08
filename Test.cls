Class DocumentTemplate.Test
{

/// Load all test documents in the database from the <var>directory</var>
ClassMethod LoadTestDocs(directory)
{
	set namesList = $LB("SimpleTextSubstitution",
						"ExpressionSubstitution",
						"ExpressionSubstitution",
						"IfParagraph",
						"IfRows",
						"OrderTableRows",
						"OrderTableRowsAndColumns",
						"OrderParagraph",
						"OrderTableColumns",
						"NestedOrder",
						"NestedOrderIf",
						"HeadersAndFooters"
	)
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

ClassMethod RunAllTests()
{
	set namesList = $LB("SimpleTextSubstitution",
						"ExpressionSubstitution",
						"IfParagraph",
						"IfRows",
						"OrderTableRows",
						"OrderTableRowsAndColumns",
						"OrderParagraph",
						"OrderTableColumns",
						"NestedOrder",
						"NestedOrderIf",
						"HeadersAndFooters"
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
	if error'="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("SimpleTextSubstitution.odt")
	quit error
}

ClassMethod TestExpressionSubstitution() [ ProcedureBlock = 0 ]
{
	set a = "First part"
	set b = "and second part" 
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("ExpressionSubstitution.docx")
	if error '="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("ExpressionSubstitution.odt")
	quit error
}

ClassMethod TestOrderParagraph() [ ProcedureBlock = 0 ]
{
	kill paragraph
	set paragraph(1) = "Appear weak when you are strong, and strong when you are weak"
	set paragraph(2) = "The supreme art of war is to subdue the enemy without fighting"
	set paragraph(3) = "If you know the enemy and know yourself, you need not fear the result of a hundred battles. If you know yourself but not the enemy, for every victory gained you will also suffer a defeat. If you know neither the enemy nor yourself, you will succumb in every battle."
	set paragraph(4) = "Let your plans be dark and impenetrable as night, and when you move, fall like a thunderbolt."
	set paragraph(5) = "Supreme excellence consists of breaking the enemy's resistance without fighting."  
	set paragraph(6) = "All warfare is based on deception. Hence, when we are able to attack, we must seem unable; when using our forces, we must appear inactive; when we are near, we must make the enemy believe we are far away; when far away, we must make him believe we are near."
	
	//set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("OrderParagraph.docx")
	//if error '="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("OrderParagraph.odt")
	quit error
}

ClassMethod TestOrderTableRows() [ ProcedureBlock = 0 ]
{
	for i=1:1:15{
		set firstColumn(i)="firsRow "_i
	}
	for j=1:1:10{
		set secondColumn(j)="secondRow"_j
	}
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("OrderTableRows.docx")
	if error'="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("OrderTableRows.odt")
	quit error
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
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("OrderTableColumns.docx")
	if error'="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("OrderTableColumns.odt")
	quit error
}

ClassMethod TestOrderTableRowsAndColumns() [ ProcedureBlock = 0 ]
{
	kill table
	for i=1:1:10{
		for j=1:1:5{
			set table(i,j)="r "_i_"c "_j
		}
	}
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("OrderTableRowsAndColumns.docx")
	quit error
}

ClassMethod TestIfParagraph() [ ProcedureBlock = 0 ]
{
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("IfParagraph.docx")
	if error '="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("IfParagraph.odt")
	quit error
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
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("IfRows.docx")
	if error '="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("IfRows.odt")
	quit error
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
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("NestedOrder.docx")
	if error '="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("NestedOrder.odt")
	quit error
}

ClassMethod TestNestedOrderIf() [ ProcedureBlock = 0 ]
{
	kill paragraphs
	for i=1:1:13{
		for j=1:1:11{
			set paragraphs(i,j) = "word "_i_" "_j
		}
	}
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("NestedOrderIf.docx")
	if error '="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("NestedOrderIf.odt")
	quit error
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
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("HeadersAndFooters.docx")
	if error '="" quit error
	set error = ##class(DocumentTemplate.DocumentTemplate).RenderDocument("HeadersAndFooters.odt")
	quit error
}

}
