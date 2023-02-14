/*
*  Steve Berley - steve@leftpropeller.com
*/
trigger DataSummaryTrigger on Data_Summary__c (before insert, before update, before delete, after insert, after update, after delete) {
    
    if(trigger.isBefore && !trigger.isDelete ) {
        for (data_summary__c ds : trigger.new) {
            if (trigger.isInsert) DataSummaryHandler.autoSetVals(ds, null);
            else DataSummaryHandler.autoSetVals(ds, trigger.oldMap.get(ds.id));
        }
    }
}