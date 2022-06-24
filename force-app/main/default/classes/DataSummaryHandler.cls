/*
*  Steve Berley - steve@leftpropeller.com
*/
public with sharing class DataSummaryHandler {
    // public DataSummaryTriggerHandler() { }
    
    public static void autoSetVals(Data_Summary__c ds){
        if ( string.isBlank(ds.Child_Object__c) ) {
            ds.Child_Relationship_Name__c = null;
            ds.Relationship_Field_Child__c = null;
        } 
        
        else {
            summaryTask.RelInfo childRel = summaryTask.genRelInfo(ds.Parent_Object__c, ds.Child_Object__c);
            if (ds.Relationship_Field_Child__c == null && childRel.rel != null) ds.Relationship_Field_Child__c = childRel.rel;
            if (ds.Child_Relationship_Name__c == null && childRel.crn != null) ds.Child_Relationship_Name__c = childRel.crn;       
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


    // public static void setDefaultTimestamp(Data_Summary__c is, Data_Summary__c was){
    //     string last = 'last_';
    //     string current = summaryTask.timestampCurrent;
    //     string previous = summaryTask.timestampPrevious;

    //     if (was == null) {
    //         // was is null when called from an insert query
    //         if ( !string.isblank(is.Where_Clause__c) && is.Where_Clause__c.toLowerCase().contains(last) ) is.Timestamp__c = previous;
    //         else is.Timestamp__c = current;
    //     }

    //     else {
    //         // since was != null, we know it's an update query.  if timestamp is blank - always evaluate for retroing.
    //         if ( !string.isblank(is.Where_Clause__c) && ( string.isblank(is.Timestamp__c) 
    //             || ( (string.isblank(was.Where_Clause__c) || is.Where_Clause__c.tolowercase() != was.Where_Clause__c.tolowercase())) )) {
    //             // if the where clause is not currently blank and previously either was blank or is just different from how it is now...
    //             if ( !string.isblank(is.Where_Clause__c) && is.Where_Clause__c.toLowerCase().contains(last) ) is.Timestamp__c = previous;
    //             else is.Timestamp__c = current;    
    //         }
    //     }
    // }
}