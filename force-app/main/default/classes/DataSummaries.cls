/*
*  Steve Berley - steve@leftpropeller.com
*  This class does the work of Data Summaries and Snapshots while summaryTask provides the job control
*/
public class DataSummaries implements Database.Batchable<sObject>, Database.Stateful {
    public summaryTask st; 
    public string comma = ', ';
    public map<id, sObject> Snapshots;  // map<parent object id, summary/snapshot record>
    public integer counter = 0;
    public set<id> parentIDs = new set<id>();
    map<id, list<sObject>> childMap;

    public DataSummaries(summaryTask param1) {
        if (param1 == null) st = new summaryTask(null);
        else st = param1;
    }
 

    public Database.QueryLocator start(Database.BatchableContext BC) {
        counter++;

        // below uses st.parentFilterQuery to create a set of record ids for filtering the parent query
        // why not use a query in an inner join? Some objects don't allow being in the inner join query, notably Tasks
        getParentIDs(database.query(st.parentFilterQuery), st.relFieldChild);
        string q = st.parentQuery;  
        if ( st.pass == summaryTask.pass2 ) {
            getParentIDs(database.query(q), 'id');    
            q = st.outliersQuery; 
        }

        Database.QueryLocator ql;
        try { 
            ql = Database.getQueryLocator(q);
        }
        catch (Exception e){
            system.assert(false, st.pass + '  --  '+ e);
        }
        return ql;
    }
    
    
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        if (scope == null || scope.size() == 0) return;
        if (st.pass == summaryTask.pass2) clearFields(scope);
        else runSnapshots(scope);
    }
    
    
    public void finish(Database.BatchableContext BC) {
        if (counter > 10) return;

        if ( st.ClearOutliers && st.pass == summaryTask.pass1 ){      
            st.pass = summaryTask.pass2;  // if it was running the first pass, start the second which processes the outliers.
            startNow(st);
        } 
        
        else { 
            st.endTask();  // once the second pass is complete, close outthe task...

            // if not running one specific task, call summaryTask to find and execute the next task due to run
            if ( !st.runningSpecifiedTask ) summaryTask.startAllNow();  
        }
    }


    public static void startNow(summaryTask st){
        if (st != null) database.executebatch(new DataSummaries(st), st.batchSize);
    }


    public void runSnapshots(List<sObject> scope){
        // scope is a list of parent records 
        map<id, sObject> recsToUpdate = new map<id, sObject>();
        // list<sObject> recsToUpdate = new list<sObject>();

        getParentIDs(scope, 'id');  // load the parentIDs for the provided scope       
        getSnapshotRecords();  
        getChildRecords();

        for (sObject parent : scope){
            id parentID = parent.id;

            if ( childMap == null || childMap.size() == 0 || !childMap.containsKey(parentID) ) continue;
            List<sObject> children = childMap.get(parentID);
    
            for (string field : st.fieldSpecs.keySet()){
                Data_Summary_Field__c f = st.fieldSpecs.get(field);
                string action = f.How_to_Summarize__c.toLowerCase();
                if (action.contains('copy') || action.contains('echo')) doEcho(parentID, children, f, action);
                if (action == 'count') doCount(parentID, children, f);
                if (action == 'sum') doSum(parentID, children, f);
                if (action == 'max') doMax(parentID, children, f);
                if (action == 'min') doMin(parentID, children, f);
                if (action == 'average') doAvg(parentID, children, f);
                if (action == 'oldest value') doOldestValue(parentID, children, f);
                if (action == 'newest value') doNewestValue(parentID, children, f);
                if (action == 'median') doMedian(parentID, children, f);
                if (action.tolowercase().contains('unique values')) doUniques(parentID, children, f, action);
                if (action.tolowercase().contains('standard deviation')) doStdDev(parentID, children, f, action);
                // if (action == 'set specific value') doSetValue(parent, children, f);
            }
            recsToUpdate.put(parentID, Snapshots.get(parentID) );
        } 
        string processName = 'DataSummaries.runSummaries';
        if (st.name != null) processName += ' [' + st.name + ']';
        lpTools.saveList('upsert', recsToUpdate.values(), processName);
    }
  
   
    //  --------  Analysis methods below


    public void doEcho(id parentID, List<sObject> children, Data_Summary_Field__c f, string action) {        
        string sourceField = string.valueOf( f.get('source_field__c') );
        Object echo = null;
        for (sObject child : children) {
            echo = getValue(st, child, sourceField);
        }
        saveSnap(parentID, f.target_field__c, echo);
    }
    
    
    public void doCount(id parentID, List<sObject> children, Data_Summary_Field__c f) {
        integer count = 0;
        if (children != null ) count = children.size();
        saveSnap(parentID, f.target_field__c, count);
    }
    
    
    public void doUniques(id parentID, List<sObject> children, Data_Summary_Field__c f, string action) {
        if (string.isblank(action)) action = 'count unique values';
        string sourceField = string.valueOf( f.get('source_field__c') );
        integer count = 0;
        set<object> uniques = new set<object>();
        for (sObject child : children) {
            object val = getValue(st, child, sourceField);
            if (action.toLowerCase().contains('ignore case')) val = ((string)val).tolowercase();
            uniques.add(val)  ;
        }

        object result;
        if (action.toLowerCase().contains('list')) {
            // below also removes curley braces
            result = uniques.toString().replace('{','').replace('}','');
        }
        else result = uniques.size();
        saveSnap(parentID, f.target_field__c, result);
    }

   
    public void doSum(id parentID, List<sObject> children, Data_Summary_Field__c f) {
        string sourceField = string.valueOf( f.get('source_field__c') );
        decimal sum = 0;
        for (sObject child : children) {
            string val = string.valueOf(getValue(st, child, sourceField));
            if (!string.isblank(val) && lptools.checkNumeric(val) )  sum += decimal.valueOf(val);
        }
        saveSnap(parentID, f.target_field__c, sum);
    }
  
    
    public void doMax(id parentID, List<sObject> children, Data_Summary_Field__c f) {
        string sourceField = string.valueOf( f.get('source_field__c') );

        object max;
        for (sObject child : children){
            object val = getValue(st, child, sourceField);
            string maxString = string.valueOf(max);
            string valString = string.valueOf(val);

            if (string.isBlank(valString) || string.isBlank(maxString)) continue;

            if (lptools.checkNumeric(valString) ){
                // evaluate as a decimal 
                if (max == null || decimal.valueOf(valString) > decimal.valueOf(maxString) ) max = val;
            }

            else {
                // evaluate as a string
                if (max == null || valString > maxString ) max = val;
            }        
        }
        saveSnap(parentID, f.target_field__c, max);
    }  
  
    
    public void doMin(id parentID, List<sObject> children, Data_Summary_Field__c f) {
        // the hoops below are to make it work correctly with generics object regardless
        // of whether the values are numeric or not
        string sourceField = string.valueOf( f.get('source_field__c') );

        object min;
        for (sObject child : children){
            object val = getValue(st, child, sourceField);
            string minString = string.valueOf(min);
            string valString = string.valueOf(val);

            if (string.isBlank(valString) || string.isBlank(minString)) continue;

            if (lptools.checkNumeric(valString) ){
                // evaluate as a decimal 
                if (min == null || decimal.valueOf(valString) < decimal.valueOf(minString) ) min = val;
            }

            else {
                // evaluate as a string
                if (min == null || valString < minString ) min = val;
            }
        }
        saveSnap(parentID, f.target_field__c, min);
    }  


    public void doAvg(id parentID, List<sObject> children, Data_Summary_Field__c f) {
        string sourceField = string.valueOf( f.get('source_field__c') );
        decimal count = 0;
        decimal sum = 0;

        for (sObject child : children){
            if ( getValue(st, child, sourceField) != null) {
                sum += (decimal) getValue(st, child, sourceField);
                count++;
            }
        }

        decimal avg = 0;
        if ( count > 0 ) avg = sum / count;
        saveSnap(parentID, f.target_field__c, avg);
    } 


    public void doOldestValue(id parentID, List<sObject> children, Data_Summary_Field__c f) {
        if (string.isBlank(st.childRecDateField)) return;
        string sourceField = string.valueOf( f.get('source_field__c') );
        date bestDate;
        object bestValue;

        for (sObject child : children){
            date d =  test.isRunningTest() ? date.today() : (date) child.get(st.childRecDateField);
            if ( getValue(st, child, sourceField) != null && (bestDate == null || d < bestDate)) {
                bestDate = d;
                bestValue = getValue(st, child, sourceField);
            }
        }
        saveSnap(parentID, f.target_field__c, bestValue);
    }    


    public void doNewestValue(id parentID, List<sObject> children, Data_Summary_Field__c f) {
        if (string.isBlank(st.childRecDateField)) return;
        string sourceField = string.valueOf( f.get('source_field__c') );
        date bestDate;
        object bestValue;

        for (sObject child : children){
            date d =  test.isRunningTest() ? date.today() : (date) child.get(st.childRecDateField);
            if ( getValue(st, child, sourceField) != null && (bestDate == null || d > bestDate)) {
                bestDate = d;
                bestValue = getValue(st, child, sourceField);
            }
        }
        saveSnap(parentID, f.target_field__c, bestValue);
    } 

    
    public void doStdDev(id parentID, List<sObject> children, Data_Summary_Field__c f, string action) {
        boolean SampleApproach = false;
        if ( !string.isBlank(action) && action.toLowerCase().contains('sample') ) SampleApproach = true;

        string sourceField = string.valueOf( f.get('source_field__c') );

        double sum = 0;
        for (sObject child : children) sum += (double) getValue(st, child, sourceField) ;
        double avg = sum / children.size();

        double sumOfDiffs = 0;
        for (sObject child : children) {
            double diff = avg - (double) getValue(st, child, sourceField);
            sumOfDiffs += (diff * diff);  // yes, it's hokey, but math.pow() isn't working properly
        }

        double denom = children.size();
        if (SampleApproach) denom--;

        double stdDev = 0;
        if ( denom > 0 ){
            stdDev = math.sqrt( sumOfDiffs / denom );
        }
        saveSnap(parentID, f.target_field__c, stdDev);
    }

    
    public void doMedian(id parentID, List<sObject> children, Data_Summary_Field__c f) {
        if (children == null || children.size()==0) return;
        string sourceField = string.valueOf( f.get('source_field__c') );
        list<decimal> vals = new list<decimal>();

        for (sObject child : children) {
            vals.add( decimal.valueOf(string.valueOf(getValue(st, child, sourceField))) );
        }
        vals.sort();
        
        decimal median;
        // NOTE: below subtracts 1 because lists are zero-based
        integer medianIndex = integer.valueOf((vals.size() + 1)/2) - 1; 
        if ( math.mod(vals.size(), 2) == 1 ) {
            // if there's an odd number of items in the list, the median is the middle element.  
            // Ex: if there are 5 items it's element 3.
            median = vals[medianIndex];        
        }
        else {
            // if there's an even number of items in the list, the median is the average of the two in the middle. 
            // Ex: if there are 6 items it's average of elements 3 and 4. 
            median = (vals[medianIndex] + vals[medianIndex+1] ) / 2;
        }       
        saveSnap(parentID, f.target_field__c, median);
    }  

   
    // public void doSetValue(id parentID, List<sObject> children, Data_Summary_Field__c f) {
    //     if ( string.isblank(f.Target_Field_Type__c) || children == null || children.size() == 0 )  return;
    //     object val;

    //     switch on f.Target_Field_Type__c.toLowerCase() {
    //         when 'double' {
    //             val = double.valueOf( f.get('Specific_Value_to_Set__c') );
    //         }
    //         when 'date' {
    //             val = date.valueOf( f.get('Specific_Value_to_Set__c') );
    //         }
    //         when 'string' {
    //             val = string.valueOf( f.get('Specific_Value_to_Set__c') );
    //         }
    //     }
    //     saveSnap(parentID, f.target_field__c, val);
    // }

    //  --------  Helper methods below


    public void getSnapshotRecords(){
        // loads all existing snapshot records for the scope and creates any additional ones that are needed
        if (parentIDs == null || parentIDs.size() == 0) return;

        // re-init with each new batch - map <parent id, snap record>
        Snapshots = new map <id, sObject>();

        // clone the IDs so we can create a destructive list of work completed
        set<id> idClones = new set<id>();
        idClones.addAll(parentIDs);
        
        for (sObject snapRec: database.query(st.snapQuery) ){
            id key = (string) snapRec.get(st.relFieldSnap);
            Snapshots.put(key, clearOutTargetFields(snapRec));  // blank out the value so it's always current
            idClones.remove(key);  // remove from clones list since handled
        }

        // all that remain in idClones are new so need a snap record created 
        for (id parent : idClones){
            sObject newRec = lpTools.genObjectRecord(st.snapObj, null);
            newRec.put(st.relFieldSnap, parent);
            newRec.put(st.snapDateField , st.snapDate);
            Snapshots.put(parent, newRec);
        }
    }


    public void clearFields(list<sObject> scope){
        // let's say you're tracking the number of opps created this month on the account record.  
        // if a given account had some created last month but none yet this month, the field 
        // would erroneously hold a value.  this cleans those "outliers". 

        for (sObject so : scope){
            so = clearOutTargetFields(so);
        }
        lpTools.saveList('update', scope, 'DataSummaries.clearFields');
    }


    public sObject clearOutTargetFields(sObject rec){
        for (string field : st.fieldSpecs.keySet()){
            Data_Summary_Field__c f = st.fieldSpecs.get(field);
            rec.put( f.target_field__c, getNull(f) );
        }
        return rec;
    }


    public set<id> getParentIDs(list<sObject> scope, string field){
        if (scope == null || scope.size() == 0 || string.isBlank(field)) return null;
        parentIDs = new set<id>();
        for (sObject so : scope) parentIDs.add( (id) so.get(field) );
        return parentIDs;
    }


    public map<id, list<sObject>> getChildRecords(){
        // while you'd be tempted to use a parent-child query in place of this less elegant appraoch, you'd ultimately find that 
        // Salesforce starts throwing "invalid query locator" and "Aggregate query has too many rows..." errors if the child query 
        // yields too many rows.  So, while not the most elegant, the approach taken is more robust in real-world Salesforce.

        // returns map<parentID, list<child records>>   
        
        childMap = new map<id, list<sObject>>();

        for (sObject child : database.query(st.childQuery)){
            id parentID = getParentID(child);

            if ( !childMap.containsKey(parentID) ) childMap.put(parentID, new list<sObject>());
            list<sObject> childRecsList = childMap.get(parentID);
            childRecsList.add(child);
            childMap.put( parentID, childRecsList );
        }
        return childMap;
    }    


    public void saveSnap(id parentID, string targetField, object value){
        if (parentID == null || targetField == null ) return;
        sObject snap = Snapshots.get(parentID) ; 
        snap.put(targetField, value); 
        Snapshots.put(parentID, snap);
    }


    public object getValue(summaryTask st, sObject so, string field){ 
        string dot = '.';
        object val;

        if ( !field.contains(dot) ) {
            string soObjName = lpTools.getSObjectName(so.id);
            Schema.SObjectType soSchema = Schema.getGlobalDescribe().get(soObjName);
            Map <String, Schema.SObjectField> soFields = soSchema.getDescribe().fields.getMap();
            
            if ( soFields.containsKey(field)) val = so.get(field);
        }
        else if (!string.isblank(st.childObj)) {
            Schema.SObjectType objSchema = Schema.getGlobalDescribe().get(st.childObj);
            Map <String, Schema.SObjectField> fieldlist = objSchema.getDescribe().fields.getMap();

            Schema.SObjectField fieldSpec = fieldlist.get(st.relFieldChild).getDescribe().getSObjectField();
            sobject relatedObj = so.getSObject(fieldSpec);
            val = relatedObj.get(field.substringAfter(dot));
        }
        return val;
    }


    public object getNull(Data_Summary_Field__c f){
        object nulling = null;
        if ( string.isNotEmpty(f.How_to_Null__c) ){
            if (f.How_to_Null__c == 'zero') nulling = 0;
            if (f.How_to_Null__c == 'blank') nulling = '';
        }
        return nulling;
    }


    public id getParentID(sobject child){
        if (child == null) return null;
        boolean parentmode = false;
        if ( string.isBlank(st.childObj) || st.childObj == st.parentObj ) ParentMode = true;  

        id parentID;
        if (ParentMode) parentID = id.valueOf( (string) child.get('id'));  //  snapshotting the parent object
        else parentID = id.valueOf( (string) child.get(st.relFieldChild));  // id of parent record
        return parentID;
    }
}
