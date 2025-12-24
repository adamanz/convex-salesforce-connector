/**
 * CDC Trigger for Contact object
 * Sends Contact changes to Convex in real-time
 */
trigger ContactCDCTrigger on ContactChangeEvent (after insert) {
    ConvexCDCService.processChangeEvents(Trigger.new, 'Contact');
}
