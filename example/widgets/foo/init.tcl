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
    my setWidget Bar BarController
    return
}
    

FooController instproc setName {fooForm} {
    my set name [$fooForm name]
    return
}


FooController instproc world {} {
    my set name "World"
}


SpindleWorker connectBaseURL "foo" FooController 
SpindleWorker connectTemplate FooController \
    [file join [file dirname [info script]] view.tml]

#SpindleWorker connectBaseURLs {
#    "foo" FooController 
#}
