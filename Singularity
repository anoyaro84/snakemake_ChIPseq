BootStrap: docker
From: ubuntu:14.04

%post
	apt-get -y update
	apt-get install -y libxp6
	apt-get -qq -y install curl tar
	curl -sSL https://repo.continuum.io/archive/Anaconda2-5.0.1-Linux-x86_64.sh -o /tmp/miniconda.sh
	curl -sSL http://collaborations.gis.a-star.edu.sg/~cmb6/kumarv1/dfilter/DFilter-v1.5.tar.gz -o /usr/local/Dfilter.tar.gz
	tar -xvf /usr/local/DFilter.tar.gz
	bash /tmp/miniconda.sh -bfp /usr/local
	rm -rf /tmp/miniconda.sh
	apt-get -qq -y install libxpm4
	apt-get -qq -y install libxtst6
	apt-get -qq -y install libxt6
	apt-get -qq -y install libxmu6
	apt-get -qq -y install python2.7
	apt-get -qq -y install gawk

	conda install -y python=2
	conda update conda

	apt-get -qq -y remove curl bzip2 tar

%environment	
	export PATH=/usr/local/bin:$PATH
	export PATH=/usr/lib/x86_64-linux-gnu/:/usr/local/bin:$PATH
	export PATH=/usr/local/DFilter1.5/:$PATH
