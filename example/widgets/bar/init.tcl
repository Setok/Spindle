Class BarController -superclass SpindleController -parameter {
    {car "Caterham"}
}

BarController set baseDir [file dirname [info script]]

SpindleWorker connectBaseURLs {
    "bar" FooController 
}
