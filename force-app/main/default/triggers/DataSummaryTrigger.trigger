/*
*  Steve Berley - steve@leftpropeller.com
*/
trigger DataSummaryTrigger on Data_Summary__c (before insert, before update, before delete, after insert, after update, after delete) {
    
    if(trigger.isBefore && !trigger.isDelete ) {
        for (data_summary__c ds : trigger.new) {
            DataSummaryHandler.autoSetVals(ds);

            // if (trigger.isInsert) DataSummaryHandler.setDefaultTimestamp(ds, null);
            // else DataSummaryHandler.setDefaultTimestamp(ds, trigger.oldMap.get(ds.id) );  // if trigger is update, pass the previous values 
        }
    }
}