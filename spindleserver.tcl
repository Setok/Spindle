set MyDir [file dirname [info script]]
lappend auto_path $MyDir

package require spindle 0.1


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

@ Httpd h2 {
    description {
	Web server with basic authentication using the Spindle worker.
    }
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