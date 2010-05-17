@ @File {
    description {
	A generic list widget. 
    }
}

Class ListController -superclass SpindleController -parameter {
    dataSource
}

ListController set baseDir [file dirname [info script]]

ListController instproc init {} {
    next
    return
}
    

ListController instproc rowAmount {} {
    my instvar dataSource

    if {[info exists dataSource]} {
	return [$dataSource rowAmount]
    }
}


ListController instproc allRowTexts {} {
    my instvar dataSource

    if {[info exists dataSource]} {
	return [$dataSource allRowTexts]
    }
}

#SpindleWorker connectBaseURLs {
#    "foo" FooController 
#}
