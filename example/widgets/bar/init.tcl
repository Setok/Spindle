Class BarController -superclass SpindleController -parameter {
    {car "Caterham"}
}

BarController set baseDir [file dirname [info script]]

#SpindleWorker connectBaseURLs {
#    "bar" FooController 
#}


SpindleWorker connectBaseURL "bar" BarController 
SpindleWorker connectTemplate BarController \
    [file join [file dirname [info script]] view.tml]
