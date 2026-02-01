# OSX Halftone Generator

This is a useless utility that generates a halftone effect on the screen, making it look like it's a magazine page, or something screenprinted. I saw a TikTok about halftones and thought it would be neat to see them on the screen. As an example, Roy Lichtenstein's art featured halftones in juxtoposition with fully saturated sections of color, always with dots that were uniform in size and spacing. 

![Crying Girl, by Roy Lichtenstein](media/roy.jpg)

From 1850 through 1990, whenever color was printed onto paper, it used a technique that could be loosely defined as 'halftone printing.' The Getty institute has a [terrific article](https://www.getty.edu/conservation/publications_resources/pdf_publications/pdf/atlas_halftone.pdf) describing the history of halftone printing and many approaches and tradeoffs that have been taken over the years. 

These days, our computer representations of visual imagery are so perfect and accurate they've lost their soul, and have nothing to day. We've Corporate Memphis'd ourselves to death. The people yearn to be made to imagine! 

This project doesn't achieve that. What it does achieve is a sort of visually interesting effect for about five minutes. I recorded a brief video to demonstrate:

<video src="media/halftone_demo.mp4" controls width="100%"></video>

The effect is achieved using the Metal graphics APIs provided by OSX. These are described in a docment at HALFTONES.md, that I believe to be no more than 10% hallucinated. Run the app with `make run` and a little control panel will show up in the toolbar. It'll need permission to screen share, and it will mess up the presentation of any liquid glass components, but you'll get a sort of halftone effect. As with everything digital, something is lost relative to the real world artifact it is attempting to replicate. 

All the same, it's a neat effect and it's fun to look at photos with it on. I've found myself wanting to zoom in to see the dots more closely, dissapointed when I cannot. Using a word processor or a terminal? Don't recommend it.

