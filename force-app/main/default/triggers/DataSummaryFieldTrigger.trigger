/*
*  Steve Berley - steve@leftpropeller.com
*/
trigger DataSummaryFieldTrigger on Data_Summary_Field__c (before insert, before update, before delete, after insert, after update, after delete) {

    if ( trigger.isBefore && !trigger.isDelete){
        for (Data_Summary_Field__c dsf : trigger.new){
            DataSummaryFieldHandler.autoSetFields(dsf);
        }
    }
}