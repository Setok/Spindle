@ @File {
    description {
	Widget for displaying a form for a user to input their name and
	for "Hello, $name" to be shown. By default 'Setok' is the name, and
	is shown if the user has not yet submitted the form.

	Additionally this uses the Bar widget to display information about
	the ultimate driving machine.
    }
}


#############################################################################
@ Class FooNameForm -superclass Form -parameter {
    name {Name inputted by user}
} {
    description {
	Form for collecting the name of a user.
    }
}
#############################################################################

Class FooNameForm -superclass Form -parameter {
    name
}


#############################################################################

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


# Connect this widget to a base URL and specify a template to render.
SpindleWorker connectBaseURL "foo" FooController 
SpindleWorker connectTemplate FooController \
    [file join [file dirname [info script]] view.tml]

