package require Tcl 8.4
package require XOTcl 1.2
catch {namespace import xotcl::*}

package require xotcl::comm::httpd 1.1
package require uri

package provide spindle 0.1

#set SpindleDir [file join ~ spindle]


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


# Default location for widgets and files
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


SpindleWorker proc connectBaseURLs {urlSpec} {
    foreach {url controllerClass} $urlSpec {	
	my set baseURLs($url) [list $controllerClass]
    }
}


@ SpindleWorker instproc respond {} { 
    description {
    }
}

SpindleWorker instproc respond {} {
    [self class] instvar baseURLs
    my instvar resourceName method formData
        
    set splitResource [split $resourceName "/"]
    
    if {[info exists baseURLs([lindex $splitResource 0])]} {
	set urlData $baseURLs([lindex $splitResource 0])
	set class [lindex $urlData 0]
	array set viewSpec [lindex $urlData 1]
	set ctrl [$class new]
	set subURL [lindex $splitResource 1]
	puts "ctrl: $ctrl, subURL: $subURL"
	if {[$ctrl procIsConnected $subURL]} {
	    $ctrl $subURL
	}
	puts $method
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
		puts "Form field: [$field set name],\
                      content: [$field set content]"
	    }
	    if {[info exists formAction]} {
		# Only actually call the submission handler if the
		# suitable submit field was passed.
		if {[$class exists formActions($formAction)]} {
		    # Get the appropriate Form class. Then build it
		    # with the form data. The form object will be
		    # destroyed on return from this method.
		    # Finally call the controller with the formAction and
		    # pass it the form.
		    set formObClass [$class set formActions($formAction)]
		    set formOb [$formObClass new -volatile]
		    foreach {field content} $fields {
			$formOb $field $content
		    }
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


Class SpindleController -parameter \
    [list \
	 [list baseDir [SpindleWorker set spindleDir]] \
	 view]


## Configure this for each controller
SpindleController set baseDir [SpindleWorker set spindleDir]


SpindleController instproc init {} {
    my instvar baseDir view

    set baseDir [[my info class] set baseDir]
    set view [TemplateView new [file join $baseDir "view.tml"]]
    $view controller [self]
    return [next]
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
    puts "templateview getHTML"
    return [namespace eval ::spindle::template [list subst $content]]
}


