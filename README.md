VectorMetaballs
===============

An Objective-C implementation of vector based metaballs, original implementation by Hannu Kankaanpää. (http://www.niksula.hut.fi/~hkankaan/Homepages/index.html)  

<img width=320 src="https://github.com/Dillion/VectorMetaballs/raw/master/metaballDemo.gif" />  

References:  
1. http://www.niksula.hut.fi/~hkankaan/Homepages/metaballs.html  
2. http://labs.byhook.com/2011/09/26/vector-metaballs/  

Issues:
Besides the issues highlighted in the original article by Hannu Kankaanpää,  
1. Path fill errors  
In certain conditions, the generated path is not suited for rendering, it becomes obvious when using fill mode. Some way of reordering the CGPath, or removing unnecessary points is required.  
2. Performance  
For better performance try using the BLAS http://www.netlib.org/blas/ or vDSP functions in Accelerate  