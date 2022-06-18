/*
*  Steve Berley - steve@leftpropeller.com
*/ 
public with sharing class DataSummaryFieldHandler { 
    // public DataSummaryFieldHandler() {    }

    public static void autoSetFields(Data_Summary_Field__c dsf){
        if (dsf.Summarize_To_Object__c != null && dsf.Target_Field__c != null) {
            dsf.Target_Field_Type__c = lpTools.getFieldType(dsf.Summarize_To_Object__c, dsf.Target_Field__c);
        } // else dsf.Target_Field_Type__c = null;

        if (dsf.Child_Object__c != null && dsf.Source_Field__c != null) {
            dsf.Source_Field_Type__c = lpTools.getFieldType(dsf.Child_Object__c, dsf.Source_Field__c);
        } // else dsf.Source_Field_Type__c = null;
    }
}