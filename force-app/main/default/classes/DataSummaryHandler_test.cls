/*
*  Steve Berley - steve@leftpropeller.com
*/
@isTest
private with sharing class DataSummaryHandler_test {

    @isTest private static void test_autoSetVals(){
        Data_Summary__c ds = new Data_Summary__c(Description__c='test', Parent_Object__c='Account', Child_Object__c='Contact', Snapshot_Object__c='Opportunity', Snapshot_Date_Field__c = 'closedate');
        insert ds;

        ds.Child_Object__c = null;
        ds.Snapshot_Object__c = null;
        update ds;
    }

    // @isTest private static void test_setDefaultTimestamp(){
    //     Data_Summary__c ds = new Data_Summary__c(timestamp__c = '', where_clause__c = 'date__c = last_month ');
    //     insert ds;

    //     ds.where_clause__c = 'date__c != null';
    //     update ds;
    // }
}