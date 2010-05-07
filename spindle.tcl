package require Tcl 8.4
package require XOTcl 1.2
catch {namespace import xotcl::*}

package require xotcl::comm::httpd 1.1
package require uri


set SpindleDir [file join ~ spindle]


@ Class Form {
    description {
	Represents the data of a form.
    }
}

Class Form


Form instproc setField {field content} {
    my set fields($field) $content
    return
}


Form instproc getField {field} {
    return [my set fields($field)]
}


@ Class SpindleWorker { 
    description {
    }
}

Class SpindleWorker -superclass Httpd::Wrk


SpindleWorker proc connectBaseURLs {urlSpec} {
    foreach {url controllerClass} $urlSpec {	
	my set baseURLs($url) [list $controllerClass]
    }
}


@ SpindleWorker instproc respond {} { 
    description {
	This method handles all responses from the webserver to the client.
	We implent here "exit", and we return the information about the  actual 
	request and  user in HTML format for all other requests.
	<p>This method is an example, how to access on the server side 
	request specific infomation.
    }
}

SpindleWorker instproc respond {} {
    [self class] instvar baseURLs
    my instvar resourceName method formData

    if {$resourceName eq "exit"} {
	set ::forever 1
	#my showVars
	#my set version 1.0;### ???? 
	#puts stderr HERE
    }
        
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
	    # Build an object based on the form data, to be passed to the
	    # form submission handler. The form object will be destroyed 
	    # on return from this method.
	    set formOb [Form new -volatile]
	    foreach field $formData {
		set name [$field set name]
		if {[string match "submit-*" $name]} {
		    set formAction [lindex [split $name "-"] 1]
		}
		$formOb setField $name [$field set content]
		puts "Form field: [$field set name],\
                      content: [$field set content]"
	    }
	    if {[info exists formAction]} {
		# Only actually call the submission handler if the
		# suitable submit field was passed.
		$ctrl $formAction $formOb
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
	 [list baseDir $SpindleDir] \
	 view]


## Configure this for each controller
SpindleController set baseDir $SpindleDir


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


namespace eval ::spindle::template {
    proc widget {name} {
	variable controller

	set widget [$controller getWidget $name]
	set view [$widget view]
	return [$view getHTML]
    }
}


TemplateView instproc init {template} {
    my set template $template
}

TemplateView instproc getHTML {} {
    my instvar controller template

    set file [open [file join [$controller baseDir] templates $template] r]
    set content [read $file]
    close $file

    set ::spindle::template::controller $controller
    puts "templateview getHTML"
    return [namespace eval ::spindle::template [list subst $content]]
}


@ Httpd h2 {
  description "Web server with basic authentication using the specialied worker"}

if {[info exists env(USER)]} {
  set USER "$env(USER)"
} elseif {[info exists env(USERNAME)]} {
  set USER "$env(USERNAME)"
} else {
  set USER unknown
}
if {$::tcl_platform(platform) eq "windows"} {
  set USER unknown
}

# Load all widget info
foreach widgetDir [glob [file join $SpindleDir widgets *]] {
    source [file join $widgetDir init.tcl]
}

Httpd h2 -port 8081 -root [glob ~/wafe] \
    -httpdWrk SpindleWorker

#    -mixin BasicAccessControl \
#    -addRealmEntry test "u1 test $USER test"  -protectDir test "" {} 

puts "#### h2 started"

#
# and finally call the event loop... 
#
vwait forever