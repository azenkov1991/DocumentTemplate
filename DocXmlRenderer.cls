Include DocumentTemplate.General

/// Render document template (docx or odt) unpacked in direcotry  <var>Directory</var>
/// Lexical parser successively passes through character of the xml document
/// On each character it chooses a new state according to current state and table of states transitions
/// Initial state is  1 -  between tags. On last character the state must be equal to 1, otherwise error occured
/// <p>Lexical parser states:  </p>
/// <p>  1 Between tags  </p>
/// <p>  "{" - 2  </p>
/// <p>  - 1  </p>
/// <p>  2 First tag character was found "{"  </p>
/// <p>  "{" - 3  </p>
/// <p>  "%" - 4  </p>
/// <p>  - 1  </p>
/// <p>  3 Inside the tag {{ }}  </p>
/// <p>  "}" - 5  </p>
/// <p>  - 3  </p>
/// <p>  4 Inside the tag {% %}  </p>
/// <p>  "%" - 6  </p>
/// <p>  - 4  </p>
/// <p>  5 First character } of closing braces {{ }}  </p>
/// <p>  "}" - 1  </p>
/// <p>  - 3  </p>
/// <p>  6 First character % of closing braces {% %}  </p>
/// <p>  "}" - 1 </p>
/// <p>  - 4  </p>
Class DocumentTemplate.DocXmlRenderer Extends %RegisteredObject
{

/// Unpacked document directory
Property Directory As %String;

/// XML.Document
Property XMLDocument As %XML.Document;

Property XMLDocumentMainNodeId As %String;

Property XMLWriter As %XML.Writer;

/// States map 
Property LexicalStates [ MultiDimensional ];

/// Current state
Property LexicalCurrentState;

/// States history
Property LexicalStateHistory As %List;

/// Store xml node ids of current tag
/// Whole tag wil be moved to the first node
Property CurrentTagNodes [ MultiDimensional ];

/// Store xml node ids of current tag as a list
Property CurrentTagNodesList As %List;

/// Nodes marked for deleting
Property ToDeleteNodes [ MultiDimensional ];

/// store  'if' tags
/// IfTags(startTagNodeId) = endTagNodeId
/// IfTags(startTagNodeId, "expression") = "conditional expression" 
Property IfTags [ MultiDimensional ];

/// Stack for nested 'if' tags
Property IfTagsStack As %List;

/// Store order-tags
/// OrderTags(startTagNodeId) = endTagNodeId
/// OrderTags(startTagNodeId, "mas") = "Name of the global"
/// OrderTags(startTagNodeId, "index") = "index variable for passing through global nodes"
Property OrderTags [ MultiDimensional ];

/// Stack for nested 'order' tags
Property OrderTagsStack As %List;

/// Store 'order' or 'if' tags
/// Using for catching error
Property TagTypeStack As %String;

/// Store set-tag
/// setTags(setTagNodeId) = ""
/// setTags(setTagNodeId, "variable") = "variable for assignment"
/// setTags(setTagNodeId, "expression") = "expression"
Property SetTags [ MultiDimensional ];

/// Store if-siblings 
Property IfSiblings [ MultiDimensional ];

/// Store order sibling
Property OrderSiblings [ MultiDimensional ];

/// Store nodes marked for deletion if they are empty
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
	set documentFileDocx = ##class(%File).NormalizeFilename("word/document.xml", $this.Directory)
	set documentFileOdt = ##class(%File).NormalizeFilename("content.xml", $this.Directory)
	if ##class(%File).Exists(documentFileDocx){
		quit ..RenderDocx()
	}
	elseif ##class(%File).Exists(documentFileOdt){
		quit ..RenderOdt()
	}
	else{
		quit "Unsupported file format"
	}
}

Method RenderDocx() As %String
{
	set documentFile = ##class(%File).NormalizeFilename("word/document.xml", $this.Directory) 

	// Render main document
	set error = ..RenderXml(documentFile)
	if error'="" quit error
	do ..WriteDebug("Main document is rendered")
		
	// Render footers
	set footerExist = 1
	set footerCounter = 1
	while footerExist{
		set footerFile = ##class(%File).NormalizeFilename("word/footer"_footerCounter_".xml", $this.Directory)
		if ##class(%File).Exists(footerFile){
			set error = ..RenderXml(footerFile)
			if error'="" quit 
			do ..WriteDebug("Footer is rendered")
			set footerCounter = $I(footerCounter)
		}
		else{
			set footerExist = 0
		}
	}
	if error'="" quit error
	
		
	// Render headers
	set headerExist = 1
	set headerCounter = 1
	while headerExist{
		set headerFile = ##class(%File).NormalizeFilename("word/header"_headerCounter_".xml", $this.Directory)
		if ##class(%File).Exists(headerFile){
			set error = ..RenderXml(headerFile)
			if error'="" quit 
			do ..WriteDebug("Header rendered")
			set headerCounter = $I(headerCounter)
		}
		else{
			set headerExist = 0
		}
	}
	if error'="" quit error
	
	do ..WriteDebug("render complete")
	quit ""
}

Method RenderOdt()
{
	set documentFile = ##class(%File).NormalizeFilename("content.xml", $this.Directory) 

	// Render main document
	set error = ..RenderXml(documentFile)
	if error'="" quit error
	do ..WriteDebug("Main document is rendered")
	
	set styleFile = ##class(%File).NormalizeFilename("styles.xml", $this.Directory)
	set error = ..RenderXml(styleFile)
	if error'="" quit error
	do ..WriteDebug("Style documnet is rendered") 
	quit ""
}

/// Render xml 
/// Return error string or "" if no errors occured
Method RenderXml(fullPathToXml As %String) As %String
{
	do ..ClearState()
	
	set docFullFileName = fullPathToXml
	set xmlReader = ##class(%XML.Reader).%New()
	set sc = xmlReader.OpenFile(docFullFileName)
	if $$$ISERR(sc) quit sc
	set ..XMLDocument = xmlReader.Document
	
	set mainDocumentNode = ..XMLDocument.GetNode(..XMLDocument.GetDocumentNode())
	set ..XMLDocumentMainNodeId = mainDocumentNode.NodeId
	d ..TraverseXmlTree(.mainDocumentNode,"WriteXmlNode")
	
	set error = ..TraverseXmlTree(.mainDocumentNode,"SpecialTreatment")
	if error'="" quit error
	
	// First passing through the tree - check the syntax and  move lexem in one xml node 
	// {{ sometext }} {% sometext %}
	
	set error = ..TraverseXmlTree(.mainDocumentNode,"LexicalParse")
	if error'="" quit error
	
	// If state is not equal to 1 then error occured
	if "3,5" [..LexicalCurrentState quit "Unclosed tag {{ }}"
	if "4,6" [..LexicalCurrentState  quit "Unclosed tag {% %}"
	do ..WriteDebug("Lexical parsing is completed")
	
	d ..DeleteMarkedNodes()
	do ..WriteDebug("Nodes was deleted")
	
	do ..WriteDebug("Tree after parsing: ")
	d ..TraverseXmlTree(.mainDocumentNode,"WriteXmlNode")
	
	// Separate tags in one xml node into individual nodes
	set error = ..TraverseXmlTree(.mainDocumentNode,"SeparateTags")
	if error'="" quit error
	do ..WriteDebug("Separating is completed")
	
	// Check syntax and find tags order,if, set
	set error = ..TraverseXmlTree(.mainDocumentNode,"SyntaxParse")
	if error'="" quit error
	do ..WriteDebug("Syntax parsing is completed")
	
	// Check unclosed tags
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
		quit "Unclosed tag "_$S(unclosedOrder:"Order",1:"If")_": "_ tagText
	}
		
	// Processing IfTags and OrderTags
	
	// Find siblings for repetition in order loop
	do ..FindSiblings($Name(..OrderTags), $Name(..OrderSiblings))
	// Find siblings for repetition in if loop
	do ..FindSiblings($Name(..IfTags), $Name(..IfSiblings))
	
	
	// Write result
	d xmlReader.Close()
	set ..XMLWriter = ##class(%XML.Writer).%New()
	set ..XMLWriter.Charset="UTF-8"
	set sc = ..XMLWriter.OutputToFile(docFullFileName)
	if $$$ISERR(sc) quit $system.OBJ.DisplayError(sc)
	set error = ..Processing(.mainDocumentNode)
	if error'="" quit error
	
	
	
	quit ""
}

/// Pass through  <var>xmlNode</var> from left to right calling  <var> method </var on each node
/// <var>method </var> takes xml node as an argument
/// <var>method1</var> - calling before child elements
/// <var>method2</var> - calling after child elements
/// Return string with error or "" if  no error occured
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

/// Method is used as TraverseXmlTree argument
/// Find tags, store in stack their position
/// Return string with error or "" if  no error occured
Method LexicalParse(xmlNode) As %String
{
	set text = ""
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
				// if end of the tag was found assemble the tag in one xml node
				if ($D(..CurrentTagNodes) && (char="}") ) {
					
					// if something else in the node put tag characters before
					// to ensure that there is no different tags parts in one node
					if (i <$length(text)){
						set newNodeId = ..InsertNodeBefore(.xmlNode,$E(text, 1, i))
						
						do ..DeleteLastNodeFromTagNodeList(xmlNode.NodeId)
						do ..PushToCurrentTagNodesList(newNodeId)
						
						// All the rest stay in current node
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

Method SpecialTreatment(ByRef node)
{
	set nodeId = node.NodeId
	if node.QName="text:p"{
		// Loop through child nodes
		// characer nodes replaced with <text:span>
		if node.HasChildNodes(1){
			d node.MoveToFirstChild(1)
			set siblingsExist = 1
			while siblingsExist{
				if node.NodeType=$$$xmlTEXTNODE{
					set childNodeId = node.NodeId
					set nodeData = node.NodeData
					do node.MoveToParent()
					set newNodeId = node.InsertElement("span", "", .childNodeId, nodeData, "text:span")
					set node = ..XMLDocument.GetNode(childNodeId)
					d node.Remove()
					set node = ..XMLDocument.GetNode(newNodeId)
					//do node.ReplaceElement("span", "", node.NodeData, "text:span")
				}
					
				set siblingsExist = node.MoveToNextSibling(1)
				
			}
			d node.MoveToParent()
		}
	}
	if node.QName="text:s"{
		// <text:s> replaced with spaces
		set spaceCount = node.GetAttributeValue("c")
		if spaceCount'>0 set spaceCount=1
		set replaceStr = ""
		for i=1:1:spaceCount set replaceStr=replaceStr_" "

		do node.ReplaceCharacter(replaceStr)
	}			
	quit ""
}

Method NextLexicalState(char)
{
	// Take next state from state table
	if $D(..LexicalStates(..LexicalCurrentState,char)){
		set ..LexicalCurrentState = ..LexicalStates(..LexicalCurrentState,char)
	}
	// If there is no state then go to the default state
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

Method DeleteLastNodeFromTagNodeList(value)
{
	if $LI(..CurrentTagNodesList,*)=value{
		set value = $$$PopFromStack(..CurrentTagNodesList)
		kill ..CurrentTagNodes(value)
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
	// If tag in one xml node there's nothing to do
	if $LISTLENGTH(..CurrentTagNodesList)=1 d ..DeleteCurrentTagNodes() quit
	do ..WriteDebug("Begin tag moving")
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
	
	// tag assemle in nodeText 
	while $LISTNEXT(..CurrentTagNodesList, ptr, nodeId){
		set node = ..XMLDocument.GetNode(nodeId)
		try{
			d node.GetText(.nodeText)
		}
		catch{
		}
		do ..WriteDebug("Node marked for deletion: "_node.NodeId)
		set ..ToDeleteNodes(node.NodeId)=""
	}
	do ..ReplaceNode(.mainNode, nodeText)
		
	do ..WriteDebug("Assembling tag in one node is completed. Tag: "_nodeText)

	k testText
	k nodeText
	d ..DeleteCurrentTagNodes()
}

Method DeleteMarkedNodes()
{
	set nodeId=""
	for{
		set nodeId = $Order(..ToDeleteNodes(nodeId),-1)
		quit:nodeId=""
	try{
		set node = ..XMLDocument.GetNode(nodeId)
		do node.Remove()
		do ..WriteDebug("Node "_node.NodeId_" "_nodeId_ "deleted")	
	}
	catch error{
		do ..WriteDebug(error.Name_" "_error.Location)
	}

	}
}

/// Traverse XML and writing nodes 
/// Processing 'if' 'order' and 'set' tags
Method Processing(ByRef node As %XML.Node) As %String
{
	// processing if
	set error =""
	set expression=1
	if ($D(..IfSiblings(node.NodeId))){
		
		try{
			set expression = ..EvaluateExpression(..IfSiblings(node.NodeId,"expression"))
			d ..WriteDebug("Condition "_..IfSiblings(node.NodeId,"expression")_" "_expression)
		}
		catch exeption{
			set error = "Erroe while 'if' condition evaluating : "_..IfSiblings(node.NodeId,"expression")_$C(13,10)_exeption.DisplayString()
		}
		if error'="" quit error
		
		// Mark node with closing tag for deleting if it empty
		set ..SkipIfEmptyNodes(..IfSiblings(node.NodeId))=""
		
		// If condition is false go to last sibling
		// i.e skip block inside 'if'
		if 'expression{
			set node = ..XMLDocument.GetNode(..IfSiblings(node.NodeId))
			quit ""
		}else{
			if ..IsNodeEmpty(node){
				d node.MoveToNextSibling()
			}
		}
		
	}
	if error'="" quit error
	// processing 'order'
	// ..OrderSiblings(node.NodeId,"calculating")=1 - mark that node under processing
	// otherwise infinite loop occour
	if ($D(..OrderSiblings(node.NodeId))&&($G(..OrderSiblings(node.NodeId,"calculating"))'=1)){
		set endSiblingNodeId = ..OrderSiblings(node.NodeId)
		set startSiblingNodeId = node.NodeId
		set indexRef = ..OrderSiblings(node.NodeId,"index")
		set masRef = ..OrderSiblings(node.NodeId,"mas")
		s ..OrderSiblings(startSiblingNodeId, "calculating")=1
		do ..WriteDebug("Loop through array "_masRef_" "_indexRef)
		do ..DeclareIndex(indexRef)
		//Loop through array using declared index
		set infiniteLoopProtector = 0
		for{
			try{
				set index = ..OrderMas(masRef, indexRef)
				set infiniteLoopProtector = infiniteLoopProtector + 1
				do ..WriteDebug("Inside the array "_masRef_" index "_indexRef_" "_index)
			}
			catch exeption{
				set error = "Error while order processing: "_..OrderSiblings(node.NodeId,"mas")_$C(13,10)_exeption.DisplayString()
			}
			quit:index=""
			quit:error'=""
			if infiniteLoopProtector > $G(^DocumentPatternSettings("maxOrderIterations"),"128000"){
				set error="Infinite loop protection, number of iterations is more than "_$G(^DocumentPatternSettings("maxOrderIterations"),"128000")
				quit
			}
			set siblingsExist = 1
			// Skip first sibling if it is empty
			if ..IsNodeEmpty(node){
				set siblingsExist = node.MoveToNextSibling()
			}
			// loop through siblings
			while siblingsExist{
				// Skip last sibling if it is empty
				if node.NodeId=endSiblingNodeId && ..IsNodeEmpty(node){
					quit
				}
				set error = ..Processing(.node)
				if error'="" quit 
				set siblingsExist = node.MoveToNextSibling()
			}
			quit:error'=""
			// Before the next repetition go to the first sibling
			set node = ..XMLDocument.GetNode(startSiblingNodeId)
		}
		quit:error'="" error
		s ..OrderSiblings(startSiblingNodeId, "calculating")=0
		do ..KillIndex(indexRef)
		// After the order the last sibling became current node
		set node = ..XMLDocument.GetNode(endSiblingNodeId)
		quit ""
	}
	if error'="" quit error
	
	// Processing set
	if ($D(..SetTags(node.NodeId)))
	{
		try{
			set value = ..EvaluateExpression(..SetTags(node.NodeId,"expression"))
		}
		catch exeption{
			set error = "Error while evaluating 'set' expression : "_..SetTags(node.NodeId,"expression")_$C(13,10)_exeption.DisplayString()
		}
		quit:error'="" error
		try{
			d ..SetVariable(..SetTags(node.NodeId,"variable"),value)
		}
		catch exeption{
			set error = "Error while variable assignment: "_..SetTags(node.NodeId,"variable")_$C(13,10)_exeption.DisplayString()
		}
	}
	// Skip nodes marked as empty
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

/// Write xml node and evaluate it. Used as  TraverseXml argument
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
	//Write all attributes
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
		// if expression then evaluate it
		if $match(text,"\{\{.+\}\}"){
			set expression= $ZSTRIP($P($P(text,"{{",2),"}}",1),"<>W")
			try{
				set result = ..EvaluateExpression(expression)
			}
			catch exeption{
				set error="Error while evaluating expression: "_expression_$C(13,10)_exeption.DisplayString()
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

/// End of writing xml node. Used as TraverseXml argument
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

Method SeparateTags(node As %XML.Node) As %String
{
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
		//finding tag
		set start = 0
		set end = 0
		set tag = ""

		set start = $LOCATE(text,"\{[%\{].*[%\}]\}", start, end, tag)
		if start=0 quit
		// .* - greedy qualifier
		// find inside text closing lexem
		set closeBracket = $S($E(text,start+1)="{":"\}",1:"%")_"\}" // closeBracket = %} or }}
		set closeBracketIndex = $Locate(text, closeBracket,start)
		
		// if closing lexem was found shorten it
		if (closeBracketIndex'=0) && ((closeBracketIndex + 2) < end){
			set end = closeBracketIndex + 2
			set tag = $E(text,start, end-1)
		}
		
		// insert text before tag into the xml node before
		// all the rest remains in current node
		if start>1{
			set newNodeText = $E(text,1,start-1)
			do ..InsertNodeBefore(.node, newNodeText)
			do ..WriteDebug("Text1: "_text_" splitted on "_newNodeText_" and "_$E(text,start,*))
			set text=$E(text,start,*)
			continue
		}
		// if characters after tag exists  then insert the copy of xml node with tag before the current node 
		// all the rest remains in current node
		
		if end '> $L(text){
			do ..InsertNodeBefore(.node, tag)
			do ..WriteDebug("Text2: "_text_" splitted on "_tag_" and "_$E(text,end,*))
			set text = $E(text,end,*)
			continue
		}
		set tagExist=0
	}
	do ..ReplaceNode(.node, text)
	quit ""
}

/// Insert copy of xml node before  with given text
/// Return id of the new node
Method InsertNodeBefore(ByRef node As %XML.Node, text As %String) As %String
{
	do ..WriteDebug("Insert node before, node name "_node.QName_" , text "_text)
	
	set nodeId = node.NodeId
	set QName = node.QName
	set localName = node.LocalName
	set namespace = node.Namespace
	
	set nodeAttributes = ""
	do ..SaveNodeAttributes(.node, .nodeAttributes)
	
	
	d node.MoveToParent()
	set text = ..Replaceon160(text)
	set newNodeId = node.InsertElement(localName, namespace, nodeId, text, QName)
	
	// Back on current node
	set node = ..XMLDocument.GetNode(newNodeId)
	
	set attributeName = ""
	do ..SetAttributesToNode(.node, .nodeAttributes)

	// Node wil be the same as before
	d node.MoveToNextSibling()
	do ..SetAttributesToNode(.node, .nodeAttributes)
	
	quit newNodeId
}

/// Set node attributes
/// nodeAttributes - array of node attributes
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

/// Save node attributes in array nodeAttributes
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
	// ending space replaced whith nonbreaking space
	set text = ..Replaceon160(text)
	do node.ReplaceElement(node.LocalName, node.Namespace, text, node.QName)
	do ..SetAttributesToNode(.node, .nodeAttributes)
}

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

/// Syntax parsers. Used as  TraverseXml argument
/// Check the sytax, saves tag information
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
	
	// Check 'endorder' tag
	if $locate(text, beginOfEndOrderRegExp)'=0{
		set fullEndOrderRegExp = beginOfEndOrderRegExp_"\s*"_"%\}"
		set isEndOrderCorrect = $match(text, fullEndOrderRegExp)
		if 'isEndOrderCorrect quit "Incorrect sytax of  'endorder' tag: "_text
		set currentTagType = $$$PopFromStack(..TagTypeStack)
		if currentTagType="" quit "Unexpected 'endorder', must be preceded by 'order'"
		if currentTagType'="order" quit "Unexpected 'endorder', expecting closing of "_currentTagType
		set orderTagNodeId = ..PopFromOrderStack()
		set ..OrderTags(orderTagNodeId) = node.NodeId
	}
	
	// Check 'Order' tag
	
	elseif $locate(text,beginOfOrderRegExp,0)'=0{
		set fullOrderRegExp = beginOfOrderRegExp_"\s+"_anyVariableRegExp_"\s+"_variableRegExp_"\s*"_"%\}"
		set isOrderCorrect = $match(text, fullOrderRegExp)
		if 'isOrderCorrect quit "Incorrect sytax of  'order' tag: "_text
		$$$PushToStack(..TagTypeStack,"order")
		d ..PushToOrderStack(node.NodeId)
		// find array name
		// Skip order
		set val = "", start = 0
		set start = $locate(text, beginOfOrderRegExp_"\s+", start , end, val)
		set start = end
		set start = $locate(text, anyVariableRegExp, start ,end , val)
		set start = end
		set ..OrderTags(node.NodeId,"mas") = val
		// find index
		set start = $locate(text, variableRegExp, start , end, val)
		set ..OrderTags(node.NodeId,"index") = val
	}
	
	// Check 'endif' tag
	
	elseif $locate(text, beginOfEndIfRegExp, 0)'=0{
		set fullEndIfRegExp = beginOfEndIfRegExp_"\s*"_"%\}"
		set isEndifCorrect = $match(text, fullEndIfRegExp)
		if 'isEndifCorrect quit "Incorrect sytax of  'endif' tag: "_text
		set currentTagType = $$$PopFromStack(..TagTypeStack)
		if currentTagType="" quit "Unexpected 'endif', must be preceded by 'if'"
		if currentTagType'="if" quit "НUnexpected 'endif', expecting closing of  "_currentTagType
		set ifTagNodeId = ..PopFromIfStack()
		set ..IfTags(ifTagNodeId) = node.NodeId
	}
	
	// Check 'if' tag
	
	elseif $locate(text,beginOfIfRegExp,0)'=0{
		set fullIfRegExp = beginOfIfRegExp_"\s+"_".+"_"\s*"_"%\}"
		set isIfCorrect = $match(text, fullIfRegExp)
		if 'isIfCorrect quit "Incorrect sytax of  'if' tag: "_text
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
		if 'isSetCorrect quit "Incorrect sytax of  'set' tag: "_text
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
		quit "Unknown tag: "_text	
	}
	// Delete text of the tag
	do ..ReplaceNode(.node, "")
	quit ""
}

/// Find siblings for repetition or conditional output
/// ref - array reference  with xml nodes in which tags is contained
/// refResult - result array referece with xml nodes which will be repeated in the future or skipped in case of 'if' tag processing
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
		// Copy tag parameters
	    merge @refResult@(firstSiblingNodeId) = @ref@(firstNodeId)
	    set @refResult@(firstSiblingNodeId) = lastSiblingNodeId 
	}
}

/// Check if the node and his children are empty
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

/// Evaluate expression in global namespace
ClassMethod EvaluateExpression(expression) [ ProcedureBlock = 0 ]
{
	do ..WriteDebug("Evaluate expression "_expression)
	// Replace quotes with ordinary quotes ,
	set expression = $Replace(expression,$C(8221),"""")
	set expression = $Replace(expression,$C(8220),"""")
	set expression = $Replace(expression,$C(8217),"'")
	set expression = $xecute("quit "_expression)
	quit $Replace(expression,"_"," ")
}

/// Declare index in global namespace
ClassMethod DeclareIndex(indexRef) [ ProcedureBlock = 0 ]
{
	do ..WriteDebug("Declare index "_indexRef)
	set @indexRef=""
}

///  Apply order in global namespace
ClassMethod OrderMas(masRef, indexRef) [ ProcedureBlock = 0 ]
{
	set @indexRef = $Order(@masRef@(@indexRef))
	quit @indexRef
}

ClassMethod KillIndex(indexRef) [ ProcedureBlock = 0 ]
{
	do ..WriteDebug("Index is killed "_indexRef)
	k @indexRef
}

/// Assinging in global namespace
ClassMethod SetVariable(variableRef, value) [ ProcedureBlock = 0 ]
{
	do ..WriteDebug("Set variable "_variableRef_" ="_value)
	set @variableRef = value
}

/// Return CommonAnscestor of two xml nodes or "" if they don't have one
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
				do ..WriteDebug(xmlNode.NodeId_" Name: "_xmlNode.QName_"; text: "_text)
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
