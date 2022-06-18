/*
*  Steve Berley - steve@leftpropeller.com
*/
@isTest
private class DataSummaryFieldHandler_test {
    
    @isTest static void test_all(){
        Data_Summary__c ds = new Data_Summary__c(Parent_Object__c='Account', Child_Object__c='Contact', Snapshot_Object__c='opportunity');
        insert ds;

        Data_Summary_Field__c dsf = new Data_Summary_Field__c(summary__c=ds.id, Target_Field__c='name', Source_Field__c='lastname');
        insert dsf;
    }
}