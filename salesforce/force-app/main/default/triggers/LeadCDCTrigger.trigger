/**
 * CDC Trigger for Lead object
 * Sends Lead changes to Convex in real-time
 */
trigger LeadCDCTrigger on LeadChangeEvent (after insert) {
    ConvexCDCService.processChangeEvents(Trigger.new, 'Lead');
}
