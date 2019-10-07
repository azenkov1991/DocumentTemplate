Include DocumentTemplate.General

/// Выполняет генерацию шаблона документа docx распакованного в директорию <var>Directory</var>
/// При парсинге лексический парсер выполняет последовательно проход по символам документа
/// На каждом символе происходит выбор нового состояния в зависимости от текущего состояния и символа
/// Начальное состояние 1 -  Между тэгами. На поседнем символе должно быть состояние 1, иначе ошибка
/// <p>Состояния лексического парсера:  </p>
/// <p>  1 Между тэгами  </p>
/// <p>  "{" - 2  </p>
/// <p>  - 1  </p>
/// <p>  2 Найден первый символ тэга "{"  </p>
/// <p>  "{" - 3  </p>
/// <p>  "%" - 4  </p>
/// <p>  - 1  </p>
/// <p>  3 Внутри тэга {{ }}  </p>
/// <p>  "}" - 5  </p>
/// <p>  - 3  </p>
/// <p>  4 Внутри тэга {% %}  </p>
/// <p>  "%" - 6  </p>
/// <p>  - 4  </p>
/// <p>  5 Первый сивол закрывающегося тэга {{ }}  </p>
/// <p>  "}" - 1  </p>
/// <p>  - 3  </p>
/// <p>  6 Первый сивол закрывающегося тэга {% %}  </p>
/// <p>  "}" - 1 </p>
/// <p>  - 4  </p>
Class DocumentTemplate.DocXmlRenderer Extends %RegisteredObject
{

/// Директория распакованного документа
Property Directory As %String;

/// XML.Document
Property XMLDocument As %XML.Document;

Property XMLDocumentMainNodeId As %String;

Property XMLWriter As %XML.Writer;

/// Карта переходов лексического парсера
Property LexicalStates [ MultiDimensional ];

/// Текущее состояние 
Property LexicalCurrentState;

/// История состояний
Property LexicalStateHistory As %List;

/// Информация о текущем тэге
/// хранит информацию о всех узла xml в котором этот тэг присутствует
/// Весь тэг будет перенесен в перый узел, остальные будут удалены
Property CurrentTagNodes [ MultiDimensional ];

Property CurrentTagNodesList As %List;

/// Узлы помеченые на удаление
/// Во время обхода нельзя удалять узлы, так как ломается путь обхода
Property ToDeleteNodes [ MultiDimensional ];

/// Массив для хранения тэгов if
/// IfTags(startTagNodeId) = endTagNodeId
/// IfTags(startTagNodeId, "expression") = "Выражение условия тэга" 
Property IfTags [ MultiDimensional ];

/// Стэк для хранения вложенности if-ов
Property IfTagsStack As %List;

/// Массив для хранения тэгов order 
/// OrderTags(startTagNodeId) = endTagNodeId
/// OrderTags(startTagNodeId, "mas") = "Имя узла который обходим"
/// OrderTags(startTagNodeId, "index") = "Имя переменной, которую использовать для обхода узла"
Property OrderTags [ MultiDimensional ];

/// Стэк для хранения вложенных order-ов
Property OrderTagsStack As %List;

/// Для хранения тэга order или if
/// Используется чтобы отловить ошибку закрытия не того тэга
Property TagTypeStack As %String;

/// Массив для хранения тэгов set
/// setTags(setTagNodeId) = ""
/// setTags(setTagNodeId, "variable") = "Переменная, в которую присваевается значение"
/// setTags(setTagNodeId, "expression") = "Вычисляемое выражение"
Property SetTags [ MultiDimensional ];

/// Массивы хранения сиблингов 
Property IfSiblings [ MultiDimensional ];

Property OrderSiblings [ MultiDimensional ];

/// для хранения узлов помеченных на удаление, если они пустые
Property SkipIfEmptyNodes [ MultiDimensional ];

Method %OnNew(directory As %String) As %Status
{
	set $this.Directory = directory
	
	
	set ..LexicalStates(1) = 1
	set ..LexicalStates(1,"{") = 2
	set ..LexicalStates(2) = 1
	set ..LexicalStates(2,"{") = 3
	set ..LexicalStates(2,"%") = 4
	set ..LexicalStates(3) = 3
	set ..LexicalStates(3,"}") = 5
	set ..LexicalStates(4) = 4
	set ..LexicalStates(4,"%") = 6
	set ..LexicalStates(5) = 3
	set ..LexicalStates(5,"}") = 1
	set ..LexicalStates(6) = 4
	set ..LexicalStates(6,"}") = 1
	

	quit $$$OK
}

Method ClearState()
{
	set ..LexicalCurrentState = 1
	set ..LexicalStateHistory = $LB()
	
	set ..CurrentTagNodesList=""
	set ..IfTagsStack = ""
	set ..OrderTagsStack = ""
	set ..TagTypeStack = ""
	kill ..CurrentTagNodes, ..ToDeleteNodes, ..IfTags, ..OrderTags
	kill ..IfSiblings, ..OrderSiblings, ..SkipIfEmptyNodes
}

Method Render() As %String
{
	set documentFile = ##class(%File).NormalizeFilename("word/document.xml", $this.Directory) 

	// Рендеринг основного документа
	set error = ..RenderXml(documentFile)
	if error'="" quit error
	do ..WriteDebug("Основной документ сгенерирован")
		
	// Рендеринг футеров
	set footerExist = 1
	set footerCounter = 1
	while footerExist{
		set footerFile = ##class(%File).NormalizeFilename("word/footer"_footerCounter_".xml", $this.Directory)
		if ##class(%File).Exists(footerFile){
			set error = ..RenderXml(footerFile)
			if error'="" quit 
			do ..WriteDebug("Футер сгенерирован")
			set footerCounter = $I(footerCounter)
		}
		else{
			set footerExist = 0
		}
	}
	if error'="" quit error
	
		
	// Рендеринг хедеров
	set headerExist = 1
	set headerCounter = 1
	while headerExist{
		set headerFile = ##class(%File).NormalizeFilename("word/header"_headerCounter_".xml", $this.Directory)
		if ##class(%File).Exists(headerFile){
			set error = ..RenderXml(headerFile)
			if error'="" quit 
			do ..WriteDebug("Header сгенерирован")
			set headerCounter = $I(headerCounter)
		}
		else{
			set headerExist = 0
		}
	}
	if error'="" quit error
	
	do ..WriteDebug("Рендеринг завршен")
	quit ""
}

/// Генерация документа
/// Возвращает строку с ошибкой, иначе ""
Method RenderXml(fullPathToXml As %String) As %String
{
	do ..ClearState()
	
	//Генерация основного документа xml
	set docFullFileName = fullPathToXml
	set xmlReader = ##class(%XML.Reader).%New()
	set sc = xmlReader.OpenFile(docFullFileName)
	if $$$ISERR(sc) quit sc
	set ..XMLDocument = xmlReader.Document
	
	set mainDocumentNode = ..XMLDocument.GetNode(..XMLDocument.GetDocumentNode())
	set ..XMLDocumentMainNodeId = mainDocumentNode.NodeId
	d ..TraverseXmlTree(.mainDocumentNode,"WriteXmlNode")
	
	// Первый проход по дереву - проверка синтаксиса и перенос лексем в один XML узел
	// {{ sometext }} {% sometext %}
	set error = ..TraverseXmlTree(.mainDocumentNode,"LexicalParse")
	if error'="" quit error
	
	// Если стостояние по выходу не 1 то ошибка
	if "3,5" [..LexicalCurrentState quit "Незакрытый тэг {{ }}"
	if "4,6" [..LexicalCurrentState  quit "Незакрытый тэг {% %}"
	do ..WriteDebug("Разбор на лексемы завершен")
	
	d ..DeleteMarkedNodes()
	do ..WriteDebug("Узлы удалены")
	
	// Разбивка тэгов по разным узлам
	set error = ..TraverseXmlTree(.mainDocumentNode,"SeparateTags")
	if error'="" quit error
	do ..WriteDebug("Завершена разбивка тэга по узлам")
	
	// Провевка синтаксиса и нахождение тэгов order,if, set
	set error = ..TraverseXmlTree(.mainDocumentNode,"SyntaxParse")
	if error'="" quit error
	do ..WriteDebug("Завершен синтаксический разбор документа")
	// Проверка незакрытых тэгов
	set unclosedIf = 0, unclosedOrder=0, nodeId=""
	if $length(..OrderTagsStack)'=0{
		set unclosedOrder = 1
		set nodeId = ..PopFromOrderStack()
	}
	if $length(..IfTagsStack)'=0{
		set unclosedIf = 1
		set nodeId = ..PopFromIfStack()
	}
	if unclosedIf||unclosedOrder{
		set node = ..XMLDocument.GetNode(nodeId)
		set tagText = ""
		try{
			d node.GetText(.tagText, 0)
		}
		catch{}
		quit "Незакрытый тэг "_$S(unclosedOrder:"Order",1:"If")_": "_ tagText
	}
		
	// Обработка массивв IfTags и OrderTags
	// Нахождение сиблингов для повторения и условного вывода
	do ..FindSiblings($Name(..OrderTags), $Name(..OrderSiblings))
	do ..FindSiblings($Name(..IfTags), $Name(..IfSiblings))
	
	
	// Запись результата в файл
	d xmlReader.Close()
	set ..XMLWriter = ##class(%XML.Writer).%New()
	set ..XMLWriter.Charset="UTF-8"
	set sc = ..XMLWriter.OutputToFile(docFullFileName)
	if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	set error = ..Processing(.mainDocumentNode)
	if error'="" quit error
	
	
	
	quit ""
}

/// Обход узла Xml <var>xmlNode</var> вглубину, слева на право, вызов метода <var> method </var на каждом узле
/// <var>method </var> должен принимать XmlNode
/// <var>method1</var> - вызывается до обхода дочерних элементов
/// <var>method2</var> - вызывается после обхода дочерних элементов
/// Возвращает строку с ошибкой, иначе ""
Method TraverseXmlTree(ByRef xmlNode As %XML.Node, method1 As %String, method2 As %String = "") As %String
{
	set error = $method($this, method1, .xmlNode)
	if error'="" quit error
	if xmlNode.HasChildNodes(){
		d xmlNode.MoveToFirstChild()
		set siblingsExist = 1
		while siblingsExist{
			set error = ..TraverseXmlTree(.xmlNode, method1, method2)
			if error'="" quit
			set siblingsExist = xmlNode.MoveToNextSibling()
		}
		d xmlNode.MoveToParent()
	}
	if $G(error)'="" quit error
	if method2'=""{
		set error = $method($this, method2, .xmlNode)
		if error'="" quit error
	}
	quit ""
}

/// Метод для использования в функции TraverseXmlTree
/// Ищет ключевые тэги, сохраняет в стэке их местоположения, проверяет на ошибки 
/// Возвращает строку с ошибкой, иначе ""
Method LexicalParse(xmlNode) As %String
{
	set textExist = 0
	try{
		set textExist = xmlNode.GetText(.text, 0 )
	}
	catch{	}
	if textExist && ($G(text)'=""){
		for i=1:1:$length(text){
			set char = $E(text,i)
			d ..NextLexicalState(char)
			if ..LexicalCurrentState=1{
				// Если тэг закончен, то он собирается в один узел
				if $D(..CurrentTagNodes) {
					// Если в текущем узле еще что-то есть то остаток тэга вставляется позади
					
					if (i <$length(text)){
						set newNodeId = ..InsertNodeBefore(.xmlNode,$E(text, 1, i))
						do ..PushToCurrentTagNodesList(newNodeId)
						// Оставшийся текст остается в текущем узле
						do ..ReplaceNode(.xmlNode,$E(text,i+1,*))
					}
					else{
						do ..PushToCurrentTagNodesList(xmlNode.NodeId) 
					}
					do ..StoreTagInOneNode()
				}
			}
			else {
				if ..LexicalCurrentState=2{
					do ..DeleteCurrentTagNodes()
				}
				do ..PushToCurrentTagNodesList(xmlNode.NodeId) 
			}
		}
	}
	quit ""
}

/// Переход лексического парсера в новое состояние
Method NextLexicalState(char)
{
	// Переход по карте переходов
	if $D(..LexicalStates(..LexicalCurrentState,char)){
		set ..LexicalCurrentState = ..LexicalStates(..LexicalCurrentState,char)
	}
	// Если символа в таблице переходов нет, то переход в состояние по умолчанию
	else {
		set ..LexicalCurrentState = ..LexicalStates(..LexicalCurrentState)
	}
}

Method PushToCurrentTagNodesList(value)
{
	if '$D(..CurrentTagNodes(value)){
		s ..CurrentTagNodes(value) = ""
		$$$PushToStack(..CurrentTagNodesList, value)
	}
}

Method DeleteCurrentTagNodes()
{
	k ..CurrentTagNodes
	s ..CurrentTagNodesList = ""
}

/// Перемещает содержимое тэга в первый узел его содержащий
/// Остальные узлы удаляются
Method StoreTagInOneNode()
{
	if '$D(..CurrentTagNodes) quit
	// Если тэг в одном узле то выход
	if $LISTLENGTH(..CurrentTagNodesList)=1 d ..DeleteCurrentTagNodes() quit
	do ..WriteDebug("Начало переноса в один тэг")
	set ptr = 0
	set nodeId=""
	
	set isNotEnd = $LISTNEXT(..CurrentTagNodesList,ptr,nodeId)
	if 'isNotEnd d ..DeleteCurrentTagNodes() quit
	
	set mainNodeId = nodeId
	set mainNode = ..XMLDocument.GetNode(nodeId)

	set nodeText=""
	try{
		d mainNode.GetText(.nodeText)
	}
	catch{}
	
	// В цикле собирается весь текст тэга в один XML узел
	while $LISTNEXT(..CurrentTagNodesList, ptr, nodeId){
		set node = ..XMLDocument.GetNode(nodeId)
		try{
			d node.GetText(.nodeText)
		}
		catch{
		}
		set ..ToDeleteNodes(node.NodeId)=""
	}
	do ..ReplaceNode(.mainNode, nodeText)
		
	d ..WriteDebug("Перенесен в один узел "_nodeText)
	k testText
	k nodeText
	d ..DeleteCurrentTagNodes()
	do ..WriteDebug("Перенос завршен")
}

/// Удаляет помеченные на удаление узлы
Method DeleteMarkedNodes()
{
	set nodeId=""
	for{
		set nodeId = $Order(..ToDeleteNodes(nodeId))
		quit:nodeId=""
	try{d ..XMLDocument.GetNode(nodeId).Remove()}
	catch{}

	}
}

/// Рекурсивный обход узлов XML с записью узлов в файл
/// Обработка тэгов if order set 
Method Processing(ByRef node As %XML.Node) As %String
{
	// Обработка if
	set error =""
	set expression=1
	if ($D(..IfSiblings(node.NodeId))){
		
		try{
			set expression = ..EvaluateExpression(..IfSiblings(node.NodeId,"expression"))
			d ..WriteDebug("Условие "_..IfSiblings(node.NodeId,"expression")_" "_expression)
		}
		catch exeption{
			set error = "Ошибка при вычислении условия if: "_..IfSiblings(node.NodeId,"expression")_$C(13,10)_exeption.DisplayString()
		}
		if error'="" quit error
		// Если условие не выполняется то переход к последнему сиблингу if
		// т.е пропуск блока внутри if
		if 'expression{
			// Пометка узла с завершающим тэгом на удаление если он пустой
			set node = ..XMLDocument.GetNode(..IfSiblings(node.NodeId))
			quit ""
		}else{
			set ..SkipIfEmptyNodes(..IfSiblings(node.NodeId))=""
			if ..IsNodeEmpty(node){
				d node.MoveToNextSibling()
			}
		}
	}
	if error'="" quit error
	// обработка order
	// ..OrderSiblings(node.NodeId,"calculating")=1 - пометка что этот узел уже обрабатывается
	// иначе будет бесконечный цикл
	if ($D(..OrderSiblings(node.NodeId))&&($G(..OrderSiblings(node.NodeId,"calculating"))'=1)){
		set endSiblingNodeId = ..OrderSiblings(node.NodeId)
		set startSiblingNodeId = node.NodeId
		set indexRef = ..OrderSiblings(node.NodeId,"index")
		set masRef = ..OrderSiblings(node.NodeId,"mas")
		s ..OrderSiblings(startSiblingNodeId, "calculating")=1
		do ..WriteDebug("Цикл по массиву "_masRef_" "_indexRef)
		do ..DeclareIndex(indexRef)
		// Цикл по индексу
		set infiniteLoopProtector = 0
		for{
			try{
				set index = ..OrderMas(masRef, indexRef)
				set infiniteLoopProtector = infiniteLoopProtector + 1
				do ..WriteDebug("Внутри массива "_masRef_" индекс "_indexRef_" "_index)
			}
			catch exeption{
				set error = "Ошибка при обходе массива: "_..OrderSiblings(node.NodeId,"mas")_$C(13,10)_exeption.DisplayString()
			}
			quit:index=""
			quit:error'=""
			if infiniteLoopProtector > $G(^DocumentPatternSettings("maxOrderIterations"),"128000"){
				set error="Защита от бесконечного цикла, количество итераций превысило "_$G(^DocumentPatternSettings("maxOrderIterations"),"128000")
				quit
			}
			set siblingsExist = 1
			// Если начальный сиблинг с тэгом пустой то его не надо копировать
			if ..IsNodeEmpty(node){
				set siblingsExist = node.MoveToNextSibling()
			}
			// Цикл по сиблингам
			while siblingsExist{
				// Если завершающий сиблинг с тэгом пустой то его пропускаем
				if node.NodeId=endSiblingNodeId && ..IsNodeEmpty(node){
					quit
				}
				set error = ..Processing(.node)
				if error'="" quit 
				set siblingsExist = node.MoveToNextSibling()
			}
			quit:error'=""
			// Перед следующим повторением возвращаем узел на место
			set node = ..XMLDocument.GetNode(startSiblingNodeId)
		}
		quit:error'="" error
		s ..OrderSiblings(startSiblingNodeId, "calculating")=0
		do ..KillIndex(indexRef)
		// После цикла for выход, текущим узлом становится последний сиблинг
		set node = ..XMLDocument.GetNode(endSiblingNodeId)
		quit ""
	}
	if error'="" quit error
	
	// Обработка тэга set
	if ($D(..SetTags(node.NodeId)))
	{
		try{
			set value = ..EvaluateExpression(..SetTags(node.NodeId,"expression"))
		}
		catch exeption{
			set error = "Ошибка при вычислении выражения set: "_..SetTags(node.NodeId,"expression")_$C(13,10)_exeption.DisplayString()
		}
		quit:error'="" error
		try{
			d ..SetVariable(..SetTags(node.NodeId,"variable"),value)
		}
		catch exeption{
			set error = "Ошибка при присваивании переменной: "_..SetTags(node.NodeId,"variable")_$C(13,10)_exeption.DisplayString()
		}
	}
	// Пропуск узлов, помеченных на пропуск если они пустые
	if $D(..SkipIfEmptyNodes(node.NodeId))&&..IsNodeEmpty(node) quit ""
	set error = ..WriteAndEvaluateNode1(node)
	if error'="" quit error
	if node.HasChildNodes(){
		d node.MoveToFirstChild()
		set siblingsExist = 1
		while siblingsExist{
			set error = ..Processing(.node)
			if error'="" quit
			set siblingsExist = node.MoveToNextSibling()
		}
		d node.MoveToParent()
	}
	if $G(error)'="" quit error
	set error = ..WriteAndEvaluateNode2(node)
	if error'="" quit error
	quit ""
}

/// Рекурсивная запись узла XML в файл, для использования в функции TraverseXml
Method WriteAndEvaluateNode1(node As %XML.Node)
{
	if node.QName="" quit ""
	set error = ""
	if node.NodeId=..XMLDocumentMainNodeId{
		set sc =  ..XMLWriter.RootElement(node.QName)
	}
	else{
		set sc =  ..XMLWriter.Element(node.QName)
	}
	
	if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	set attributeName = node.FirstAttributeName()
	//Запись всех атрибутов 
	while attributeName'=""{
		set name = node.GetAttributeQName(attributeName)
		set value = node.GetAttributeValue(attributeName)
		set namespace = node.GetAttributeNamespace(attributeName)
		d ..XMLWriter.WriteAttribute(name, value, namespace)
		set attributeName = node.NextAttributeName(.attributeName)
	}
	set textExist = 0
	set text=""
	try{
		set textExist = node.GetText(.text)
	}
	catch{	}
	if textExist{
		// если это выражение, оно вычисляется
		if $match(text,"\{\{.+\}\}"){
			set expression= $ZSTRIP($P($P(text,"{{",2),"}}",1),"<>W")
			try{
				set result = ..EvaluateExpression(expression)
			}
			catch exeption{
				set error="Ошибка при вычислении выражения: "_expression_$C(13,10)_exeption.DisplayString()
			}
			if error'="" quit error
			if $E(result,1,6)="XMLMOD"{
				set result=$E(result,7,*)
				do ..XMLWriter.Write(result)
			} 	
			else{
				do ..XMLWriter.WriteChars(result)
			}
		}
		else{
			do ..XMLWriter.WriteChars(text)
		}
	}
	quit error
}

/// Окончание записи узла XML
Method WriteAndEvaluateNode2(node As %XML.Node)
{
	if node.QName="" quit ""
	if node.NodeId=..XMLDocumentMainNodeId{
		d ..XMLWriter.EndRootElement()
	}
	else{
		do ..XMLWriter.EndElement()
	}
	quit ""
}

/// Выделяет тэг в отдельный XML узел, для использования в TraverseXML
Method SeparateTags(node As %XML.Node) As %String
{
	// Поиск тэга
	set textExist=0
	set text = ""
	try{
		set textExist = node.GetText(.text, 0 )
	}
	catch{	}
	if 'textExist quit ""
	set start = $LOCATE(text,"\{[%\{].*[%\}]\}")
	if start=0 quit ""
	set tagExist=1
	while tagExist{
		//Нахождение самого тэга
		set start = 0
		set end = 0
		set tag = ""

		set start = $LOCATE(text,"\{[%\{].*[%\}]\}", start, end, tag)
		if start=0 quit
		// .* - жадный квалификатор
		// Проверка есть ли внутри найденного текста закрывающая лексема
		set closeBracket = $S($E(text,start+1)="{":"\}",1:"%")_"\}" // closeBracket = %} or }}
		set closeBracketIndex = $Locate(text, closeBracket,start)
		// Если есть то укорачиваем найденый текст
		if (closeBracketIndex'=0) && ((closeBracketIndex + 2) < end){
			set end = closeBracketIndex + 2
			set tag = $E(text,start, end-1)
		}
		// если до тэга есть текст, то создается копия узла с текстом до тэга 
		// копия узла вставляется до текущего тэга
		// оставшийся текст остается в текущем узле
		if start>1{
			set newNodeText = $E(text,1,start-1)
			do ..InsertNodeBefore(.node, newNodeText)
			do ..WriteDebug("Текст1: "_text_" разделен на "_newNodeText_" и "_$E(text,start,*))
			set text=$E(text,start,*)
			continue
		}
		// если есть текст после тэга,  то создается копия узла с текстом  тэга 
		// копия узла вставляется до текущего тэга
		// оставшийся текст остается в текущем узле
		if end '> $L(text){
			do ..InsertNodeBefore(.node, tag)
			do ..WriteDebug("Текст2: "_text_" разделен на "_tag_" и "_$E(text,end,*))
			set text = $E(text,end,*)
			continue
		}
		set tagExist=0
	}
	do ..ReplaceNode(.node, text)
	quit ""
}

/// Вставляет Копию XML узла перед данным узлом с заданым текстом
/// Возвращает id нового узла
Method InsertNodeBefore(ByRef node As %XML.Node, text As %String) As %String
{
	set nodeId = node.NodeId
	set QName = node.QName
	set localName = node.LocalName
	set namespace = node.Namespace
	
	// копирование всех атрибутов в nodeAtributes, после вставки нового узла они теряются
	set nodeAttributes = ""
	do ..SaveNodeAttributes(.node, .nodeAttributes)
	
	
	d node.MoveToParent()
	set text = ..Replaceon160(text)
	set newNodeId = node.InsertElement(localName, namespace, nodeId, text, QName)
	
	// Возврат на текущий узел
	set node = ..XMLDocument.GetNode(newNodeId)
	
	
	// Копирование всех атрибутов в старый и новый узел
	set attributeName = ""
	do ..SetAttributesToNode(.node, .nodeAttributes)

	// Указатель узла возвращается в то же положение что и был до входа
	d node.MoveToNextSibling()
	do ..SetAttributesToNode(.node, .nodeAttributes)
	quit newNodeId
}

/// Установка узлу атрибутов
/// node - узел
/// nodeAttributes - массив с атрибутами
Method SetAttributesToNode(ByRef node As %XML.Node, ByRef nodeAttributes)
{
	set attributeName = ""
	for{
		set attributeName = $O(nodeAttributes(attributeName))
		quit:attributeName=""
		set name = nodeAttributes(attributeName,"name")
		set value = nodeAttributes(attributeName,"value")
		set namespace = nodeAttributes(attributeName,"namespace")
		
		do node.SetAttribute(name, namespace, value)
	}
}

/// Сохранение атрибутов узла Node в массив nodeAttributes
Method SaveNodeAttributes(ByRef node As %XML.Node, ByRef nodeAttributes)
{
	set attributeName = node.FirstAttributeName()
	set nodeAttributes = ""
	while attributeName'=""{
		set name = node.GetAttributeQName(attributeName)
		set value = node.GetAttributeValue(attributeName)
		set namespace = node.GetAttributeNamespace(attributeName)
		
		set nodeAttributes(attributeName, "name") = name
		set nodeAttributes(attributeName, "value") = value
		set nodeAttributes(attributeName, "namespace") = namespace

		set attributeName = node.NextAttributeName(attributeName)
	}
}

Method ReplaceNode(ByRef node As %XML.Node, text As %String = "")
{
	set nodeAttributes = ""
	do ..SaveNodeAttributes(.node, .nodeAttributes)
	// Пробелы в начале и конце заменяются на неразрывные, иначе они теряются
	set text = ..Replaceon160(text)
	do node.ReplaceElement(node.LocalName, node.Namespace, text, node.QName)
	do ..SetAttributesToNode(.node, .nodeAttributes)
}

/// Замена пробелов в начале и конце на неразрывные пробелы
Method Replaceon160(text)
{
	if $E(text)=" "{
		set $E(text) = $C(160)
	}
	if $E(text,*)=" "{
		set $E(text, *) = $C(160)	
	}
	quit text
}

/// Синтаксический парсер. Для использования в функции TraverseXml
/// Проверяет правильность использования тэгов и сохраняет информацию о тэгах
Method SyntaxParse(node As %XML.Node) As %String
{
	set textExist = 0
	set text = ""
	try{
		set textExist = node.GetText(.text, 0 )
	}
	catch{	}
	if 'textExist quit ""
	set isFound = $match(text,"\{%.*%\}")
	if 'isFound quit ""

	set variableRegExp = "([A-Za-z]+[A-Za-z0-9]*"_"(\(.+\)){0,1})"
	set globalVariableRegExp = "((\^)|(\^\|\|))"_variableRegExp
	set anyVariableRegExp = "(("_globalVariableRegExp_")|("_variableRegExp_"))"
	set numberRegExp = "\d+(\.\d+)?"

	set beginOfEndOrderRegExp = "\{%"_"\s*"_"(?i)endorder(?-i)"
	set beginOfOrderRegExp = "\{%"_"\s*"_"(?i)order(?-i)"
	set beginOfEndIfRegExp = "\{%"_"\s*"_"(?i)endif(?-i)"
	set beginOfIfRegExp = "\{%"_"\s*"_"(?i)if(?-i)"
	set beginOfSetRegExp = "\{%"_"\s*"_"(?i)set(?-i)\s+"
	// Проверка тэга endorder
	if $locate(text, beginOfEndOrderRegExp)'=0{
		set fullEndOrderRegExp = beginOfEndOrderRegExp_"\s*"_"%\}"
		set isEndOrderCorrect = $match(text, fullEndOrderRegExp)
		if 'isEndOrderCorrect quit "Некорректный ситаксис тэга endorder: "_text
		set currentTagType = $$$PopFromStack(..TagTypeStack)
		if currentTagType="" quit "Неожиданное появление тэга endorder, должен предшествовать тэг order"
		if currentTagType'="order" quit "Неожиданное появление тэга endorder, ожидалось завершение тэга "_currentTagType
		set orderTagNodeId = ..PopFromOrderStack()
		set ..OrderTags(orderTagNodeId) = node.NodeId
	}
	
	// Проверка тэга Order
	
	elseif $locate(text,beginOfOrderRegExp,0)'=0{
		set fullOrderRegExp = beginOfOrderRegExp_"\s+"_anyVariableRegExp_"\s+"_variableRegExp_"\s*"_"%\}"
		set isOrderCorrect = $match(text, fullOrderRegExp)
		if 'isOrderCorrect quit "Некорректный синтаксис тэга Order: "_text
		$$$PushToStack(..TagTypeStack,"order")
		d ..PushToOrderStack(node.NodeId)
		// Поиск имени массива
		// Пропуск order
		set val = "", start = 0
		set start = $locate(text, beginOfOrderRegExp_"\s+", start , end, val)
		set start = end
		set start = $locate(text, anyVariableRegExp, start ,end , val)
		set start = end
		set ..OrderTags(node.NodeId,"mas") = val
		// Поиск индекса
		set start = $locate(text, variableRegExp, start , end, val)
		set ..OrderTags(node.NodeId,"index") = val
	}
	
	// Проверка тэга endif
	
	elseif $locate(text, beginOfEndIfRegExp, 0)'=0{
		set fullEndIfRegExp = beginOfEndIfRegExp_"\s*"_"%\}"
		set isEndifCorrect = $match(text, fullEndIfRegExp)
		if 'isEndifCorrect quit "Некорректный синтаксис тэга endif:"_text
		set currentTagType = $$$PopFromStack(..TagTypeStack)
		if currentTagType="" quit "Неожиданное появление тэга endif, должен предшествовать тэг if"
		if currentTagType'="if" quit "Неожиданное появление тэга endif, ожидалось завершение тэга "_currentTagType
		set ifTagNodeId = ..PopFromIfStack()
		set ..IfTags(ifTagNodeId) = node.NodeId
	}
	
	// Проверка тэга if
	
	elseif $locate(text,beginOfIfRegExp,0)'=0{
		set fullIfRegExp = beginOfIfRegExp_"\s+"_".+"_"\s*"_"%\}"
		set isIfCorrect = $match(text, fullIfRegExp)
		if 'isIfCorrect quit "Некорректный синтаксис тэга If: "_text
		$$$PushToStack(..TagTypeStack,"if")
		d ..PushToIfStack(node.NodeId)
		set ..IfTags(node.NodeId) = ""
		// Поиск выражения If
		set start = $locate(text, beginOfIfRegExp_"\s+",0,end)
		set val = $ZSTRIP($P($E(text,end,*),"%}",1),"<>W")
		set ..IfTags(node.NodeId,"expression") = val
	}
	// Проверка тэга set 
	elseif $locate(text, beginOfSetRegExp,0)'=0{
		set fullSetRegExp = beginOfSetRegExp_variableRegExp_"\s*=\s*"_".+"_"\s*"_"%\}"
		set isSetCorrect = $match(text, fullSetRegExp)
		if 'isSetCorrect quit "Некорректный синтаксис тэга set: "_text
		set setVariable=""
		set val = "", start = 0
		set start = $locate(text, beginOfSetRegExp, start , end, val)
		set start = end
		set start = $locate(text,variableRegExp,start,end,setVariable)
		set ..SetTags(node.NodeId,"variable") = setVariable
		set setExpression = $ZSTRIP($P($P(text,"=",2),"%}",1),"<>W")
		set ..SetTags(node.NodeId,"expression") = setExpression
	}
	else{
		quit "Недопустимый тэг: "_text	
	}
	// Удаление текста тэга
	do ..ReplaceNode(.node, "")
	quit ""
}

/// Поиск узлов сиблингов для повторения или условного вывод
/// ref - ссылка на массив с узлос тэгов
/// refResult - ссылка на массив с результатами
Method FindSiblings(ref, refResult)
{
	set firstNodeId = ""
	for{
		set firstNodeId = $Order(@ref@(firstNodeId))
		quit:firstNodeId=""
		set lastNodeId = @ref@(firstNodeId)
		set firstNode = ..XMLDocument.GetNode(firstNodeId)
		set lastNode = ..XMLDocument.GetNode(lastNodeId)
		set node = ..GetCommonAnscestor(firstNode, lastNode)
		d node.MoveToFirstChild()
		set siblingsExist = 1
		while siblingsExist{
			if ..IsDescendant(node, firstNode){
				set firstSiblingNodeId = node.NodeId
			}
			if ..IsDescendant(node,lastNode){
				set lastSiblingNodeId = node.NodeId
			}
			set siblingsExist = node.MoveToNextSibling()
		}
		// Копирование параметров тэга
	    merge @refResult@(firstSiblingNodeId) = @ref@(firstNodeId)
	    set @refResult@(firstSiblingNodeId) = lastSiblingNodeId 
	}
}

/// Проверяет является ли узел или его подузлы пустыми
Method IsNodeEmpty(node As %XML.Node) As %Boolean
{
	set result = ..TraverseXmlTree(node, "NodeEmptyForTraverse","")
	if result = "" quit 1
	quit 0
}

Method NodeEmptyForTraverse(node As %XML.Node)
{
	set textExist=0
	set text = ""
	try{
		set textExist = node.GetText(.text, 0 )
	}
	catch{	}
	if textExist && (text'="") quit 0
	quit ""
}

ClassMethod ReplaceHtmlSymbols(string)
{
	set newString = $Replace(string,"<","&lt;")
	set newString = $Replace(newString,">","&gt;")
	set newString = $Replace(newString,"&","&amp;")
	set newString = $Replace(newString,"""","&quot;")
	quit newString
}

/// Функция вычисления выражения в глобальном пространстве имен
ClassMethod EvaluateExpression(expression) [ ProcedureBlock = 0 ]
{
	do ..WriteDebug("Вычисляю выражение "_expression)
	// Замена доковских кавычек на обычные,
	set expression = $Replace(expression,"”","""")
	set expression = $Replace(expression,"“","""")
	set expression = $Replace(expression,"’","'")
	set expression = $xecute("quit "_expression)
	quit $Replace(expression,"_"," ")
}

/// Объявление индекса для обхода в глобальном пространстве имен
ClassMethod DeclareIndex(indexRef) [ ProcedureBlock = 0 ]
{
	do ..WriteDebug("объявлен индекс "_indexRef)
	set @indexRef=""
}

///  Применение функции Order в глобальном пространстве имен
ClassMethod OrderMas(masRef, indexRef) [ ProcedureBlock = 0 ]
{
	set @indexRef = $Order(@masRef@(@indexRef))
	quit @indexRef
}

ClassMethod KillIndex(indexRef) [ ProcedureBlock = 0 ]
{
	do ..WriteDebug("Убит индекс "_indexRef)
	k @indexRef
}

/// присваивание значения в глобальном пространстве имен
ClassMethod SetVariable(variableRef, value) [ ProcedureBlock = 0 ]
{
	do ..WriteDebug("Установка переменной "_variableRef_" ="_value)
	set @variableRef = value
}

/// Возвращает узел общего предка двух XML узлов или "" если они не имеют
ClassMethod GetCommonAnscestor(node1 As %XML.Node, node2 As %XML.Node) As %XML.Node
{
	set node = node1.%ConstructClone()
	set anscestorNotFound = 1
	while anscestorNotFound{
		if ..IsDescendant(node, node2) {
			set anscestorNotFound=0
			quit
		}else{
			try{
				set parentExist = node.MoveToParent()
				if 'parentExist quit
			}catch{
			}
		}

	}
	if 'anscestorNotFound quit node
	quit ""
}

ClassMethod IsDescendant(parentNode As %XML.Node, node As %XML.Node) As %String
{
	set result = 0
	if node.NodeId=parentNode.NodeId quit 1	
	if parentNode.HasChildNodes(){
		d parentNode.MoveToFirstChild()
		set siblingsExist = 1
		while siblingsExist{
			set result = ..IsDescendant(.parentNode, node)
			if result=1 quit
			set siblingsExist = parentNode.MoveToNextSibling()
		}
		d parentNode.MoveToParent()
	}
	quit result
}

Method PopFromOrderStack()
{
	set value = $$$PopFromStack(..OrderTagsStack)
	quit value
}

Method PushToOrderStack(value)
{
	$$$PushToStack(..OrderTagsStack, value)
}

Method PopFromIfStack()
{
	set value = $$$PopFromStack(..IfTagsStack)
	quit value
}

Method PushToIfStack(value)
{
	$$$PushToStack(..IfTagsStack, value)
}

Method WriteXmlNode(ByRef xmlNode As %XML.Node)
{
	set textExist =0
		try{
			set textExist = xmlNode.GetText(.text, 0 )
		}
		catch{	}
			if textExist && (text'=""){
				//write !,xmlNode.NodeId,  " Text: of "_xmlNode.QName_" is "_text,
				 //" length: "_$Length(text)
			}
	quit ""
}

ClassMethod WriteDebug(string)
{
	//write !,string
	//set counter = $O(^DocumentPatternLog($J,$H,""),-1)
	//set ^DocumentPatternLog($J,$H,counter + 1,string)=""
}

}
