/**
 * CDC Trigger for Opportunity object
 * Sends Opportunity changes to Convex in real-time
 */
trigger OpportunityCDCTrigger on OpportunityChangeEvent (after insert) {
    ConvexCDCService.processChangeEvents(Trigger.new, 'Opportunity');
}
