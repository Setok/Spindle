package provide spindle 0.1

package require Tcl 8.4
package require XOTcl 1.2
catch {namespace import xotcl::*}

package require xotcl::comm::httpd 1.1
package require uri

namespace import ::tcl::mathop::*

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


SpindleWorker proc connectBaseURL {url controllerClass} {
    my set baseURLs($url) $controllerClass
}


SpindleWorker proc connectTemplate {controllerClass template} {
    my set templates([namespace which -command $controllerClass]) $template
}


SpindleWorker proc getTemplateForController {controllerClass} {
    return [my set templates([namespace which -command $controllerClass])]
}


@ SpindleWorker instproc respond {} { 
    description {
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
	set ctrl [$class new]
	$ctrl volatile

	if {[info exists templates($class)]} {
	    set view [TemplateView new $templates($class)]
	    $view volatile
	    $view controller $ctrl
	    $ctrl view $view
	}

	set subURL [lindex $splitResource 1]
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
    } else {
	my replyCode 404
	my connection puts "\n"
    }

    my close
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


Class TemplateView -superclass View


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


