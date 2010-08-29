package provide spindle 0.1

lappend auto_path [file dirname [info script]]
package require Tcl 8.5
package require XOTcl 1.6
catch {namespace import xotcl::*}
namespace import ::tcl::mathop::*

package require xotcl::comm::httpd 1.1
package require uri
package require fishpool.trycatch 1.0
namespace import ::trycatch::*

namespace eval conf {
    # Maximum length of a list of fields in a form
    set maxFieldList 4096
}


## Pad 'list' to 'length' by adding on empty elements to end of list, 
## until it reaches 'length'. If list is already at that length, or longer,
## do nothing.
## 
## Return new list with padded elements.

proc padListToLength {list length} {
    if {$length <= [llength $list]} {
	# List already at that length, or longer. Do nothing.
	return $list
    }

    for {set i [llength $list]} {$i < $length} {incr i} {
	lappend list ""
    }

    return $list
}


#############################################################################
@ Class Form {
    description {
	Represents the data of a form. This is just a non-operational base
	class for forms. Each form should have its own class which
	extends this (by sub-classing) and provides XOTcl -parameter style
	setter/getter methods for the supported fields.       
    }
}
#############################################################################

Class Form


#############################################################################
@ Class SpindleWorker -superclass Httpd::Wrk { 
    description {
	This does the main work of processing requests (after the 
	XOTcl httpd basic processing). It finds suitable controllers,
	matches them with views, builds appropriate Form objects and
	calls the connected methods.
    }
}
#############################################################################

Class SpindleWorker -superclass Httpd::Wrk


# Default location for widgets and related files. Set this to whatever
# location you are using.
SpindleWorker set spindleDir [file join ~ spindle]


@ SpindleWorker proc loadWidgets {} {
    description {
	Go through the configured Spindle directory and load in all the
	widgets from there.
    }
}

SpindleWorker proc loadWidgets {} {
    my instvar spindleDir

    # Load all widget info
    foreach widgetDir [glob [file join $spindleDir widgets *]] {
	source [file join $widgetDir init.tcl]
    }
}


@ SpindleWorker proc connectBaseURL {
    url {
	Top URL path to connect to. 
	Shouldn't contain leading and following slash.
    }
    controllerClass {Controller class that manages the URL}
} {
    description {
	Connects a base URL to a Controller class which will manage that
	URl.
    }
}

SpindleWorker proc connectBaseURL {url controllerClass} {    
    # Two-way mapping between url and controller.
    my set baseURLs($url) $controllerClass
    my set baseControllers($controllerClass) $url
}


@ SpindleWorker proc urlForController {
    controllerClass {Controller class}
} {
    description {
	Returns the URL (without leading and following slash) that is managed
	by the given Controller class.
    }
}

SpindleWorker proc urlForController {controllerClass} {
    return [my set baseControllers($controllerClass)]
}


SpindleWorker proc connectTemplate {controllerClass template} {
    my set templates([namespace which -command $controllerClass]) $template
}


SpindleWorker proc getTemplateForController {controllerClass} {
    return [my set templates([namespace which -command $controllerClass])]
}


@ SpindleWorker instproc respond {} { 
    description {
	This matches HTTP requests to controllers and views.

	It works by taking the first part of the URL path (following host
	name) and checks to see if a controller was connected to that path
	(with the connectBaseURL call). It then instantiates that
	controller. If the controller's constructor requires arguments,
	these are taken from the next parts of the URL path, one at a
	time.

	So if the "/person" URL was connected to PersonController, and
	PersonController's [init] requires one argument 'name', then
	"/person/Spock" would create a PersonController instance, with 'Spock'
	as the name argument.

	After this, the next part of the URL path, if there, is checked to 
	see if
	it matches a connected method of the PersonController (with
        [connectProcs] in Controller). If so, this method is called.
	
	So "/person/Spock/delete" would, after instantiation, attempt to
	call the [delete] method of a PersonController object.

	If the request was a POST, then the 'name' of the form's submit
	field is used to call the matching method on PersonController, such
	that a name of "submit-create" would match the [create] method on
	PersonController. The PersonController's 'formActions' array is
	used to find a matching form class (in this case, one matching
        "create"), which is initialised and set with the POST data
        (see [buildFormOb]). This is then passed to the method discovered
        above.

	If, at any time, one of these methods throws a "Redirect" 
	(using Fishpool's try-catch package), then a HTTP redirect is
	caused. The Redirect exception should have at least one option set,
	"controller", which is the Controller class we want to redirect to.
	If the exception contains the option "init" then that contains a
	list of arguments expected to be passed to the matching Controller's
	constructor. If it contains the option "call" then that is a method
	of the Controller to call after initialisation (these are all
	mapped into the target URL of the redirection).

	Finally, if no redirection occurs, and no error conditions arise,
	the View is initialised, based on a mapping between the Controller
	and a TemlateView, using [connectTemplate]. The View has its 
	controller set to the controller discovered in URL matching and the
	[getHTML] method of that TemplateView is called, thus receiving
	the HTML from that template, possibly modified by data provided
	by the controller, which is available to the template via the
	$controller variable.

	The setup of [connectBaseURL] and [connectTemplate] should be done
	in the initialisation file of the widget/controller, which is
	loaded with the call to [loadWidgets].
    }
}

SpindleWorker instproc respond {} {
    [self class] instvar baseURLs templates
    my instvar resourceName method formData
        
    set splitResource [split $resourceName "/"]
    
    if {[info exists baseURLs([lindex $splitResource 0])]} {
	set class $baseURLs([lindex $splitResource 0])
	# Make sure we have the fully qualified name
	set class [namespace which -command $class]

	# See if constructor needs arguments, which will be picked from
	# the URL path, one argument at a time.
	set initArgLength [llength [$class info instargs init]]
	set initArgs [lrange $splitResource 1 $initArgLength]
	set subURL [lindex $splitResource [+ $initArgLength 1]]
	set ctrl [$class new [concat [list -init] $initArgs]]
	$ctrl volatile

	if {[info exists templates($class)]} {
	    set view [TemplateView new $templates($class)]
	    $view volatile
	    $view controller $ctrl
	    $ctrl view $view
	}

	set subURL [lindex $splitResource 1]

	try {
	if {[$ctrl procIsConnected $subURL]} {
	    $ctrl $subURL
	}
	if {$method eq "POST"} {
	    #set formOb [Form new -volatile]
	    set fields [list]
	    foreach field $formData {
		set name [$field set name]
		if {[string match "submit-*" $name]} {
		    set formAction [lindex [split $name "-"] 1]
		} else {
		    lappend fields $name [$field set content]
		}
	    }
	    if {[info exists formAction]} {
		# Only actually call the submission handler if the
		# suitable submit field was passed.
		if {[$class exists formActions($formAction)]} {
		    set formOb [my buildFormOb \
				    [$class set formActions($formAction)] \
				    $fields]
		    $formOb volatile
		    $ctrl $formAction $formOb
		}
	    }
	}
	set view [$ctrl view]
	set result [$view getHTML]
	my replyCode 200
	my connection puts "Content-Type: text/html"
	my connection puts "Content-Length: [string length $result]\n"
	my connection puts-nonewline $result
	} catch Redirect e {
	    set url "/"
	    append url [[self class] urlForController $e(controller)]
	    if {[info exists e(init)]} {
		append url "/" [join $e(init) "/"]
	    }
	    if {[info exists e(call)]} {
		append url "/" $e(call)
	    }
	    my replyCode 302 location $url
	}
    } else {
	my replyCode 404
	my connection puts "\n"
    }

    my close
}


@ SpindleWorker instproc buildFormOb {
    formClass {
	The XOTcl class of the form to create (presumably a subclass of
	Form).
    }
    fields {
	Key-value list of the form's field keys and values.
    }
} {
    description {
	Creates and initialises a Form object, based on 'formClass', and
	sets the values of the form by accessing the form parameters.

	Each value from the 'fields' argument
	will be set in the Form object (created from formClass) with its
	matching key (using [$formOb $key $value]). Thus each key is
	assumed to have a matching setter.

	If the key has a ":#" in it,
	the field is assumed to be one part of a list of values, all 
	being part of the same field. In that case everything up until 
	the ":" is the name of the field, and everything after "#" should
	be an integer describing the index to set the value to. Indexing
	starts from 0.

	So if 'fields' has the following: 
	{email:#0 foo@bar.com email:#1 242@front.com email:#2 test@example.com}
	then in the Form object the "email" parameter will be set to the 
	following:
	{foo@bar.com 242@front.com test@example.com}

	In the 'fields' argument these numbered fields do not have to be
	in the right order.
    }
}

SpindleWorker instproc buildFormOb {formClass fields} {		    
    set formOb [$formClass new]
    foreach {field content} $fields {
	if {[string match "*:#*" $field]} {
	    # Numbered field. Expect multiple values.
	    set splitName [split $field ":"]
	    set field [lindex $splitName 0]
	    set index [string range [lindex $splitName 1] 1 end]
	    if { (! [string is integer $index]) ||
		 ($index > $::conf::maxFieldList)} {
		continue
	    }
	    if {![info exists listFields($field)]} {
		set listFields($field) [list]
	    }

	    set listFields($field) \
		[padListToLength $listFields($field) [+ $index 1]]
	    lset listFields($field) $index $content
	} else {
	    $formOb $field $content
	}
    }

    # Set values for list fields
    foreach field [array names listFields] {
	$formOb $field $listFields($field)
    }

    return $formOb
}
    

#############################################################################
@ Class SpindleController {
    description {
	Base class for all controllers.
    }
}
#############################################################################

Class SpindleController -parameter \
    [list \
	 [list baseDir [SpindleWorker set spindleDir]] \
	 view]


SpindleController set baseDir [SpindleWorker set spindleDir]


@ SpindleController instproc connectProcs {procNames} {
    description {
	Connects each procedure listed in 'procNames' of the object so that
	sub-URLs under the main connected URL of the controller will
	call the matching procedure.

	So if the object has been connected to /foo and the controller object
	has a method 'hello' which is connected with connectProcs then
	/foo/hello will call that method, before calling the view 
	that was configured for /foo.
    }
}

SpindleController instproc connectProcs {procNames} {
    foreach procName $procNames {
	my set connectedProcs($procName) ""
    }
}


SpindleController instproc procIsConnected {procName} {
    return [my exists connectedProcs($procName)]
}


SpindleController instproc setWidget {name widget} {
    my set widgets($name) $widget
}


SpindleController instproc getWidget {name} {
    return [my set widgets($name)]
}


Class View -parameter {
    controller
}


View abstract instproc getHTML {}


# Build template commands
namespace eval ::spindle::template {
    proc widget {name} {
	variable controller

	set widget [$controller getWidget $name]
	if {! [$widget exists view]} {
	    # Widget has no view set yet, so get view based on a template
	    # which should have been configured in SpindleWorker
	    set widgetClass [$widget info class]
	    set template [SpindleWorker getTemplateForController $widgetClass]
	    if {$template ne ""} {
		set view [TemplateView new $template]
		$view controller $widget
		$widget view $view
	    }	    
	}

	set view [$widget view]
	return [$view getHTML]
    }


    proc foreach {var list body} {
	set html ""
	append evalBody {
	    append html [subst $body]
	}
	::foreach $var $list {
	    append html [subst $body]
	}
	return $html
    }
}


Class TemplateView -superclass View

TemplateView instproc init {template} {
    my set template $template
}

TemplateView instproc getHTML {} {
    my instvar controller template

    #set file [open [file join [$controller baseDir] templates $template] r]
    set file [open $template r]
    set content [read $file]
    close $file

    set ::spindle::template::controller $controller
    return [namespace eval ::spindle::template [list subst $content]]
}


