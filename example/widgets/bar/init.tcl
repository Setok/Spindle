@ @File {
    description {
	A pretty dumb widget which contains information about which car
	is the ultimate driving machine. The default is 'Caterham'.
    }
}

Class BarController -superclass SpindleController -parameter {
    {car "Caterham"}
}

#SpindleWorker connectBaseURL "bar" BarController 
SpindleWorker connectTemplate BarController \
    [file join [file dirname [info script]] view.tml]
