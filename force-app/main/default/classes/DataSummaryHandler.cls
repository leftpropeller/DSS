/*
*  Steve Berley - steve@leftpropeller.com
*/
public with sharing class DataSummaryHandler {
    // public DataSummaryTriggerHandler() { }
    
    public static void autoSetVals(Data_Summary__c ds, Data_Summary__c dsOld){
        boolean objectChanged = false;
        if (dsOld == null || string.isblank(dsOld.LeftProp_DSS__Parent_Object__c) || ds.LeftProp_DSS__Parent_Object__c != dsOld.LeftProp_DSS__Parent_Object__c ) objectChanged = true;
        if (dsOld == null || string.isblank(dsOld.LeftProp_DSS__Child_Object__c) || ds.LeftProp_DSS__Child_Object__c != dsOld.LeftProp_DSS__Child_Object__c ) objectChanged = true;


        // if either the parent or child object has a value and the other is blank - make them the same
        if ( !string.isBlank(ds.LeftProp_DSS__Parent_Object__c) && string.isBlank(ds.LeftProp_DSS__Child_Object__c)){
            ds.LeftProp_DSS__Child_Object__c = ds.LeftProp_DSS__Parent_Object__c;
        }
        else if ( string.isBlank(ds.LeftProp_DSS__Parent_Object__c) && !string.isBlank(ds.LeftProp_DSS__Child_Object__c)){ 
            ds.LeftProp_DSS__Parent_Object__c = ds.LeftProp_DSS__Child_Object__c;
        }


        if ( string.isBlank(ds.Child_Object__c) ) {
            // if child is child is still blank - make it null
            ds.Child_Relationship_Name__c = null;
            ds.Relationship_Field_Child__c = null;
        }        
        else if (ds.LeftProp_DSS__Parent_Object__c == ds.LeftProp_DSS__Child_Object__c) {
            // if both the parent and child objects are the same object, then both fields below are 'id'
            ds.Relationship_Field_Child__c = 'id';
            ds.Child_Relationship_Name__c = 'id';
        }
        else {          
            summaryTask.RelInfo childRel = summaryTask.genRelInfo(ds.Parent_Object__c, ds.Child_Object__c);
            if ((ds.Relationship_Field_Child__c == null && childRel.rel != null) || objectChanged ) ds.Relationship_Field_Child__c = childRel.rel;
            if ((ds.Child_Relationship_Name__c == null && childRel.crn != null) || objectChanged) ds.Child_Relationship_Name__c = childRel.crn;       
        }


        if ( string.isBlank(ds.Snapshot_Object__c) ) {
            ds.Relationship_Field_Snapshot__c = null;
            ds.Snapshot_Relationship_Name__c = null;
        } 
        else {
            summaryTask.RelInfo snapRel = summaryTask.genRelInfo(ds.Parent_Object__c, ds.Snapshot_Object__c);
            if (ds.Relationship_Field_Snapshot__c == null && snapRel.rel != null) ds.Relationship_Field_Snapshot__c = snapRel.rel;
            if (ds.Snapshot_Relationship_Name__c == null && snapRel.crn != null) ds.Snapshot_Relationship_Name__c = snapRel.crn;                    
        }
        
        if ( string.isNotEmpty(ds.Where_Clause__c) ) ds.Where_Clause__c = summaryTask.tuneWhereClause(ds.Where_Clause__c);

        if (ds.Snapshot_Object__c != null && ds.Snapshot_Date_Field__c != null ) {
            ds.Snapshot_Date_Field_Type__c = lpTools.getFieldType(ds.Snapshot_Object__c, ds.Snapshot_Date_Field__c);
        } else ds.Snapshot_Date_Field_Type__c = null;
    }
}