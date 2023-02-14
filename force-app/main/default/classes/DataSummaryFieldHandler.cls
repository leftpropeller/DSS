/*
*  Steve Berley - steve@leftpropeller.com
*/ 
public with sharing class DataSummaryFieldHandler { 
    // public DataSummaryFieldHandler() {    }

    public static void autoSetFields(Data_Summary_Field__c dsf){
        dsf.Target_Field_Type__c = lpTools.getFieldType(dsf.Summarize_To_Object__c, dsf.Target_Field__c);
        dsf.Source_Field_Type__c = lpTools.getFieldType(dsf.Child_Object__c, dsf.Source_Field__c);
    }
}