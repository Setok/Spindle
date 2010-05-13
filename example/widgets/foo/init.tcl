Class FooNameForm -superclass Form -parameter {
    name
}


Class FooController -superclass SpindleController -parameter {
    name 
}

FooController set baseDir [file dirname [info script]]

FooController set formActions(setName) FooNameForm

FooController instproc init {} {
    next
    my set name "Setok"
    my connectProcs [list world]
    my setWidget Bar [BarController new]
    return
}
    

FooController instproc setName {fooForm} {
    my set name [$fooForm name]
    return
}


FooController instproc world {} {
    my set name "World"
}


SpindleWorker connectBaseURLs {
    "foo" FooController 
}
