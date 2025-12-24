/**
 * CDC Trigger for Account object
 * Sends Account changes to Convex in real-time
 */
trigger AccountCDCTrigger on AccountChangeEvent (after insert) {
    ConvexCDCService.processChangeEvents(Trigger.new, 'Account');
}
