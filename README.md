# as3-ga-universal-tracker

A quick and dirty class based upon Zwetan Kjukov's as3-universal-analytics SimplestTracker documentation (https://code.google.com/p/as3-universal-analytics/wiki/SimplestTracker), that allows you to create a UniveralTracker variable and start firing off Google Analytics hits from an AS3/Flex project. 

Quick example:

    var universalTracker:UniversalTracker = new UniversalTracker("UA-XXXXXXXX-X");
    universalTracker.sendEvent("Category Test","Action Test","Label");

If your analytics mode is set to app, you will also need to call after initializing the Universal Tracker :

    universalTracker.setToApplicationMode("App Name");

In addition to sending "events", you can also sent analytics hits of "pageview", "social", "screenview", "exception", and "timing".
