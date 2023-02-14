/*
*  Steve Berley - steve@leftpropeller.com
*  This class provides the job control for Data Summaries and Snapshots while DataSummaries does the actual work.  
*  System iteratively goes through the records in the Data_Summary__c object running each applicable one as it's own 
*  batch job.  "Applicable" means - Active = true and the current day matches frequency requirement.
*/
global class summaryTask implements Schedulable {
    private static final string spaceStr = ' ';
    private static final string commaStr =  ', ';
    private static final string pipeStr = '|';
    private static final string colonStr = ':';
    private static final string selectStr = ' SELECT ';
    private static final string fromStr = ' FROM ';
    private static final string whereStr = ' WHERE ';
    private static final string andStr = ' AND ';
    private static final string inStr = ' IN ';
    private static final string notInStr = ' NOT IN ';
    private static final string parenOpen = ' ( ';
    private static final string parenClose = ' ) ';
    private static final string parentIDsStr = ' :ParentIDs ';
    
    global boolean testMode = test.isRunningTest();

    // global static final string pass0 = '0-Cleanout';
    global static final string pass1 = '1-Summary';
    global static final string pass2 = '2-Outliers';
    private static final string timeframeDaily = 'daily';
    private static final string timeframeWeekly = 'weekly';
    private static final string timeframeMonthly = 'monthly';
    private static final string timeframeQuarterly = 'quarterly';
    private static final string timeframeYearly = 'yearly';
    private static final string timeframeFY = 'fy';
    private static final string ready = 'Ready';
    private static final date today = date.today();
    // private static final date today = date.newinstance(2022,7,1); // useful for testing

    global id taskID; 
    global string name;

    // parentQuery pulls all parent records that are relevant to the task at hand
    global string parentQuery{
        get {
            if (string.isBlank(parentQuery)) genParentQuery();
            return parentQuery;
        } set;
    }     

    // childQuery pulls all child records which are to be analyzed and summarized 
    global string childQuery{
        get {
            if (string.isBlank(childQuery)) genchildQuery();
            return childQuery;
        } set;
    }

    global string childQueryTimeFilter{
        get {
            if (string.isBlank(childQueryTimeFilter)) genQueryTimeFilters();
            return childQueryTimeFilter;
        } set;
    }

    // snapQuery pulls all existing snapshot records that are relevant to the task
    global string snapQuery{
        get {
            if (string.isBlank(snapQuery)) genSnapQuery(ds);
            return snapQuery;
        } set;
    }

    global string snapQueryTimeFilter{
        get {
            if (string.isBlank(snapQueryTimeFilter)) genQueryTimeFilters();
            return snapQueryTimeFilter;
        } set;
    }

    // outliersQuery pulls all existing snapshot records in the timeframe that have been created in the past but are no longer releveant (likely because the underlying data changed) and need the target fields cleared out.
    global string outliersQuery{
        get {
            if (string.isBlank(outliersQuery)) genOutliersQuery();
            return outliersQuery;
        } set;
    }

    // contextFilter is the part of a where clause used to ensure we're only looking at the correct subset of parent or snapshot 
    // records based on the tasks' paraemters.  It's impact is it keeps the execution efficient.
    global string contextFilter{
        get {
            if (string.isBlank(contextFilter)) genContextFilter();
            return contextFilter;
        } set;
    }
    
    global Data_Summary__c ds;
    global string parentObj;
    global string childObj;
    global string snapObj;
    global string crn;
    global string childRecDateField;
    global string frequency;
    global date snapDate;
    global string snapDateField;
    global string relFieldChild;  
    global string relFieldSnap;  
    global string whereClause;
    global string taskStatus;
    global integer batchSize = 50;
    global string pass = pass1;
    global boolean runSnapshots = true;
    global boolean ClearOutliers = false;
    global boolean EchoMode = false;
    global boolean runningSpecifiedTask = false;
    global boolean specifiedSnapDate = false;
    global boolean currentTimePeriod = true;    // ex: current month vs previous month
    global map<string, Data_Summary_Field__c> fieldSpecs;   // map<field on source object, field details record>


    global summaryTask(id param1) {
        if ( !string.isblank(param1)) {
            runningSpecifiedTask = true;
            loadNextSummaryTask(param1);
        }
        else loadNextSummaryTask(null);
    }

    
    global void execute(SchedulableContext SC) {
        // looks for a task to run and start the first one that's found.
        startAllNow();
    }


    global class RelInfo{
        global string rel;
        global string crn;
    }

                
    global static integer fyStartMonth{
        get {
            if (fyStartMonth == null || fyStartMonth == 0) {
                fyStartMonth = lpTools.fyStartMonth;
            }
            return fyStartMonth;
        } set;
    } 


    // ------------ Below are about job control and job logging (start/end)
    
    @invocableMethod (label='Start a Data Summary Task (summaryTask)')
    global static list<boolean> SummaryTaskInvocable(list<string> tasks){
        // to call this from a flow - pass {!recordID} as the parameter
        if ( tasks != null && tasks.size() > 0) {
            for (string task : tasks){
                string taskID = task.substringBefore(pipeStr);
                string sched = task.substringAfter(pipeStr);

                if (!string.isBlank(taskID)) startTaskNow(taskID); // if there's a task, run it.
                if (!string.isBlank(sched)) setSchedule(sched); // if there's a sched, schedule it.
            }
        }
        return isScheduled();
    }


    global static void startAllNow(){
        // Effectively starts all tasks that are due.
        // This is accomplished by just running the next one due with runningSpecifiedTask = false
        // being set to false tells DataSummaries to call this method again get the next task to run, and so on
        // this is just a wrapper since passing a null to startTaskNow() tells it grab the next due task.
        startTaskNow(null);
    }


    global static summaryTask startTaskNow(string taskID){
        // Starts the selected task.  
        summaryTask st = new summaryTask( taskID );

        // safety in case there was no task returned (taskID = record id)
        if (string.isBlank(st.taskID)) return null;

        st.startDataSummaries();
        return st; // returns the task since it's only running one
    }


    global static list<boolean> isScheduled(){
        // determines if DSS is scheduled.  if not, the Run Now flow prompts the user to schedule it
        boolean scheduled = false;
        list<AsyncApexJob> jobs = [SELECT id FROM AsyncApexJob WHERE JobType = 'ScheduledApex' AND Status = 'Queued' AND ApexClass.NamespacePrefix = 'LeftProp_DSS' AND ApexClass.Name = 'summaryTask' ];
        if (jobs != null && jobs.size() > 0) scheduled = true;
        return new list<boolean>{scheduled};
    }


    global static void setSchedule(string timeToSchedule){
        // sets the schedule for future runs
        // timeToSchedule will come in as "|hr:min", though the pipeStr will already have been removed.
        if (string.isBlank(timeToSchedule)) return;

        string hr = timeToSchedule.substringBefore(colonStr).trim();
        if (string.isBlank(hr)) hr = '0'; // default to 0 = midnight

        string min = timeToSchedule.substringAfter(colonStr).trim();
        if (string.isBlank(min)) min = '47'; // default to 47 minutes after the hour

        // now schedule the task
        string job = 'Data Summary Tasks';
        string cron = '0 ' + min + spaceStr + hr + ' * * ?';
        system.schedule(job, cron, new summaryTask(null) );
    }


    global static void AbortStuckJobs(){
        // maintenance method - just finds all stuck jobs in queue to execute and kills them
        set<string> PendingStatuses = new set<string>{'holding'};
        list<AsyncApexJob> jobs = [SELECT id FROM AsyncApexJob WHERE JobType = 'ScheduledApex' AND ApexClass.NamespacePrefix = 'LeftProp_DSS' AND ApexClass.Name = 'DataSummaries' AND status IN :PendingStatuses ];

        for (AsyncApexJob j : jobs) system.abortJob(j.id);
    }


    global void startDataSummaries(){
        if ( this != null ) {
            // set the timestamp for starting the task if on the first pass 
            if (pass == pass1) startTask();  
            DataSummaries.startNow(this);
        }
    }
      
    
    global void startTask(){
        if (taskID == null) return;
        integer maxLen = 131072;
        Data_Summary__c t = new Data_Summary__c (id=taskID, Last_Started__c=datetime.now());
        // to make debugging easier, below saves the last used queries to hidden fields in the task
        if (!string.isblank(childQuery)) t.debug_Child_Query__c = childQuery.abbreviate(maxLen);
        if (!string.isblank(parentQuery)) t.debug_Parent_Query__c = parentQuery.abbreviate(maxLen);
        if (!string.isblank(snapQuery)) t.debug_Snapshot_Query__c = snapQuery.abbreviate(maxLen);
        if (!string.isblank(outliersQuery)) t.debug_Outliers_Query__c = outliersQuery.abbreviate(maxLen);
        lpTools.saveRec('update', t, 'summaryTask.completedTask');
    }
        

    global void endTask(){
        if (taskID == null) return;
        Data_Summary__c t = new Data_Summary__c (id=taskID, Last_Completed__c=datetime.now());
        lpTools.saveRec('update', t, 'summaryTask.completedTask');
    }


    // ------------ Below are about running a task

    global summaryTask loadNextSummaryTask(id param1){
        taskID = null;
        if ( !string.isBlank(param1) ) taskID = param1;

        // get the specified task or the next one to process
        list<Data_Summary__c> tasks = database.query(genTaskQuery(taskID));
        if (tasks == null || tasks.size() == 0) return null;
        ds = tasks[0];

        // populate instance variables based on the found task 
        if ( string.isBlank(taskID) ) taskID = ds.id;
        name = ds.name;
        parentObj = ds.Parent_Object__c;
        childObj = ds.Child_Object__c;
        if  ( ds.Snapshot_Object__c != null ) snapObj = ds.Snapshot_Object__c;

        crn = ds.Child_Relationship_Name__c;
        relFieldChild = ds.Relationship_Field_Child__c;
        if ( !string.isBlank(ds.Relationship_Field_Snapshot__c)) relFieldSnap = ds.Relationship_Field_Snapshot__c;
        if  ( !string.isBlank(ds.Date_Field_on_Child_Record__c) ) childRecDateField = ds.Date_Field_on_Child_Record__c;
        if ( ds.batch_size__c != null && ds.batch_size__c > 0) batchSize = (integer) ds.batch_size__c;

        if (ds.Where_Clause__c != null) whereClause =  tuneWhereClause(ds.Where_Clause__c) ;

        if ( !string.isBlank(ds.Snapshot_Date_Field__c) ) snapDateField = ds.Snapshot_Date_Field__c;

        if (string.isBlank(ds.Frequency__c) ) return null;
        
        frequency = ds.frequency__c.tolowercase();
    
        if (!string.isblank(ds.Task_Status__c)) taskStatus = ds.Task_Status__c;  // helps with debugging 
        
        snapDate = today;
        if (ds.Snapshot_As_Of_Date__c != null) {
            // default to today, but if a specific one was set, use it and adjust the flag.
            specifiedSnapDate = true;
            snapDate = ds.Snapshot_As_Of_Date__c;
        }

        if (ds.Clear_Outliers__c) ClearOutliers = true;

        fieldSpecs = loadFieldSpecs(ds);

        return this;
    }
     
    
    global map<string, Data_Summary_Field__c> loadFieldSpecs(Data_Summary__c ds) {
        // loads the related Data_Summary_Field__c records in to the map fieldSpecs<field name, Data_Summary_Field__c>
        fieldSpecs = new map<string, Data_Summary_Field__c>();
        for (Data_Summary_Field__c f : ds.Data_Summary_Fields__r ){
            if ( !string.isBlank(f.target_field__c) ){
                fieldSpecs.put(f.target_field__c, f);    
            }
        }
        return fieldSpecs;
    }
    
    
    global string genParentQuery(){
        // generates the query that pulls set of relevant parent records for the summarization process.  
        // Querying the actual child records happens elsewhere.  This is done so all child records are pulled at once for a given parent.

        parentQuery = selectStr + ' id  ' + fromStr + parentObj;
        if ( parentObj == childObj || string.isBlank(childObj)) {
            if (!string.isBlank(whereClause)) parentQuery += whereStr + whereClause;
        }
        else if (!string.isBlank(contextFilter)) parentQuery += whereStr + 'id' + inStr + contextFilter;
        return parentQuery;
    }
    

    global string genSnapQuery(Data_Summary__c ds){
        // snapQuery finds the records already existing in the snapshot object.  the query result is used 
        // to prevent the creation of duplicate snapshot records for a given timeframe
        // returns:  SELECT id, target fields FROM snapObj WHERE date = snapDate

        // uses the set to make sure no field is added to the query more than once
        set<string> fieldNames = new set<string>{'id'}; 
        if ( !string.isBlank(relFieldSnap)) fieldNames.add(relFieldSnap);
        if ( !string.isBlank(snapDateField)) fieldNames.add(snapDateField);
        
        for (Data_Summary_Field__c dsf : fieldSpecs.values() ){
            if ( !string.isBlank(dsf.Target_Field__c) ) fieldNames.add(dsf.Target_Field__c); 
        }
        snapQuery = selectStr + setToString(fieldNames);
        snapQuery += fromStr + snapObj;
        snapQuery += whereStr + relFieldSnap + inStr + parentIDsStr;
        if (!string.isBlank(snapQueryTimeFilter)) snapQuery += andStr + snapQueryTimeFilter;

        // oq = oq.removeStart(andStr);


        
        return snapQuery;
    }


    global string genContextFilter(){
        // the contextFilter limits the records to be processed to those in the correct context based on the parent object id
        // in the following: SELECT id FROM contact WHERE id IN ( SELECT Contact__c FROM Country_Visited__c WHERE date__c = THIS_MONTH )
        // the sub query inside the WHERE IN (xxx) is the filter query.
        // in the example its: SELECT Contact__c FROM Country_Visited__c WHERE date__c = THIS_MONTH

        // below keeps it both safe and lazy, all in one line
        if (relFieldChild == null || childObj == null) return '';

        contextFilter = parenOpen + selectStr + relFieldChild;
        contextFilter += fromStr + childObj;
        if ( !string.isBlank(whereClause) ) { 
            contextFilter += whereStr + whereClause ;
            if (!String.isBlank(childQueryTimeFilter)) contextFilter += andStr + childQueryTimeFilter;
        }
        else if (!String.isBlank(childQueryTimeFilter)) contextFilter += whereStr + childQueryTimeFilter;
        
        contextFilter += parenClose;
        return contextFilter;
    }
    

    global string genChildQuery(){
        // childQuery pulls all of the relevant child records for a given set of parents.  these are the records to be analyzed
        // uses the set to make sure no field is added to the query more than once
        set<string> fieldNames = new set<string>{'id'}; 
        if (!string.isBlank(relFieldChild)) fieldNames.add(relFieldChild);
        if (!string.isBlank(childRecDateField)) fieldNames.add(childRecDateField);
        for (Data_Summary_Field__c f : fieldSpecs.values()) fieldnames.add(f.Source_Field__c);  

        childQuery= selectStr + setToString(fieldNames);

        if (!string.isBlank(childObj)) {
            // when there's a child object - the typical scenario - query that object
            childQuery += fromStr + childObj;
            childQuery  +=  whereStr + relFieldChild + inStr + parentIDsStr;    
        }
        else {
            // when the child object is blank then the query is actually of the parent object
            childQuery += fromStr + parentObj;
            childQuery  +=  whereStr + ' id ' + inStr + parentIDsStr;
        }
        if ( !string.isBlank(whereClause) ) childQuery += andStr + whereClause;
        if ( !string.isBlank(childRecDateField) && !string.isBlank(frequency)) childQuery += andStr + childQueryTimeFilter;
        return childQuery;
    }


    global void genQueryTimeFilters(){
        // generates the time filters needed for the child and snap queries 
        // adjusts the snapDate to ensure it's the last day of the proper time period.

        date startDate;
        date endDate;
        string phrase = '';
        integer prevPeriodOffsetMonths = 0;

        if (frequency != 'Last 12 Months' 
            && (frequency.contains('prev') || frequency.contains('last'))) currentTimePeriod = false;


        if (frequency.toLowerCase().contains('day') || frequency.toLowerCase().contains('daily')) {
            // the simplicity of days makes them a special case.
            endDate = snapDate;
            if (!currentTimePeriod) endDate = endDate.addDays(-1);
            if (!string.isBlank(childRecDateField)) phrase = childRecDateField + ' = ' + lpTools.javaDateFormat(endDate);
        }

        else if (frequency.toLowerCase() == 'last 12 months') {
            startDate = date.newInstance(snapDate.year()-1, snapDate.month(), 1);
            endDate = startDate.addMonths(12);    
            if (startDate == today && !specifiedSnapDate) currentTimePeriod = false;
        }

        else if (frequency.toLowerCase().contains('month')) {
            startDate = date.newInstance(snapDate.year(), snapDate.month(), 1);
            endDate = startDate.addMonths(1);    
            prevPeriodOffsetMonths = -1;
            if (startDate == today && !specifiedSnapDate) currentTimePeriod = false;
        }

        else if (frequency.toLowerCase().contains('quarter')) {
            integer month = snapDate.month();
            integer quarterStart;
            if (month >= 1 && month < 4) quarterStart = 1;
            else if (month >= 4 && month < 7) quarterStart = 4;
            else if (month >= 7 && month < 10) quarterStart = 7;
            else if (month >= 10) quarterStart = 10;
            startDate = date.newInstance(snapDate.year(), quarterStart, 1);
            endDate = startDate.addMonths(3);    
            prevPeriodOffsetMonths = -3;
            if (startDate == today && !specifiedSnapDate) currentTimePeriod = false;
        }

        else if (frequency.toLowerCase().contains('fy')) {
            integer month = snapDate.month();
            integer year = snapDate.year();

            if (month < fyStartMonth) year--;  // implies the FY started in the previous calendar year
            startDate = date.newInstance(year, fyStartMonth, 1);
            endDate = startDate.addMonths(12);    
            prevPeriodOffsetMonths = -12;
            if (startDate == today && !specifiedSnapDate) currentTimePeriod = false;
        }

        else if (frequency.toLowerCase().contains('year')) {
            startDate = date.newInstance(snapDate.year(), 1, 1);
            endDate = startDate.addMonths(12);    
            prevPeriodOffsetMonths = -12;
            if (startDate == today && !specifiedSnapDate) currentTimePeriod = false;
        }


        if (startDate != null && endDate != null && string.isblank(phrase)){
            this.snapDate = endDate.addDays(-1);  // ensures the snap date aligns with the end of the period.

            // adjust dates to accomodate the previous period
            if (!currentTimePeriod) {
                startDate = startDate.addMonths(prevPeriodOffsetMonths);    
                endDate = endDate.addMonths(prevPeriodOffsetMonths);        
            }

            // if phrase has not yet been set...
            if (!string.isBlank(childRecDateField)) {
                phrase = childRecDateField + ' >= ' + lpTools.javaDateFormat(startDate);
                phrase += andStr + childRecDateField + ' < ' +  lpTools.javaDateFormat(endDate);        
            }
            snapDate = endDate.addDays(-1); // set the snap date to the end of the period, ie, day before the endDate
        }
        childQueryTimeFilter = '';
        if (!string.isBlank(phrase)) childQueryTimeFilter = parenOpen + phrase + parenClose;

        // set the time filte for the snapQuery
        snapQueryTimeFilter = '';
        if (!string.isBlank(snapDateField)) snapQueryTimeFilter = parenOpen + snapDateField + ' = ' + lpTools.javaDateFormat(snapDate) + parenClose;
    }


    global string genOutliersQuery(){
        // Let's say you're tracking the number of opps created this month for an account.  If an account had just one opportunity
        // created during the month and that opp was subsequently deleted, still during the month, the count would be wrong.  This 
        // generates a query of snapshot records which identifies these "outliers" and is used to clear them out.

        // below ensures each field only shows once in the query
        set<string> fieldNames = new set<string>{'id'}; 
        if ( !string.isBlank(relFieldSnap)) fieldNames.add(relFieldSnap);
        for (Data_Summary_Field__c dsf : fieldSpecs.values() ){
            if ( !string.isBlank(dsf.Target_Field__c) ) fieldNames.add(dsf.Target_Field__c); 
        }

        string fieldCriteria = '';
        for (string field : fieldNames){
            if (fieldSpecs.containsKey(field)){
                Data_Summary_Field__c f = fieldSpecs.get(field);
                if (f.Target_Field__c != null) fieldCriteria +=  genQueryNullString(f) + ' OR ';
            }
        }
        if ( !string.isBlank(fieldCriteria) )  fieldCriteria =  parenOpen + fieldCriteria.trim().removeEndIgnoreCase('OR')  + parenClose; 
        
        outliersQuery = selectStr + ' id ' + fromStr + snapObj + whereStr;
        if (!string.isblank(fieldCriteria)) outliersQuery += fieldCriteria + andStr;
        outliersQuery += snapQueryTimeFilter; 

        outliersQuery += andStr + relFieldSnap + notInStr + parentIDsStr;
        return outliersQuery;
    }


    global string genTaskQuery(id taskID){
        // generates the query string used for querying tasks (data_summary_c records) to be processed
        string q = 'SELECT id, Parent_Object__c, Child_Object__c, Child_Relationship_Name__c, Last_Completed__c, Snapshot_Object__c, Name,  Snapshot_Date_Field__c, Snapshot_mode__c, Echo_Mode__c, Relationship_Field_Child__c, Frequency__c, Where_Clause__c, Process_Data__c, Delay_Months__c, Delay_Days__c, batch_size__c, Relationship_Field_Snapshot__c, Snapshot_As_Of_Date__c, Date_Field_on_Child_Record__c, Task_Status__c, Clear_Outliers__c, ( SELECT Source_Field__c, Target_Field__c, Reset_Value_After_Snapshot__c, Target_Field_Type__c, How_to_Summarize__c, How_to_Null__c, Specific_Value_to_Set__c FROM Data_Summary_Fields__r WHERE Field_Status__c = :ready) FROM Data_Summary__c  '; 
        
        string filterClause = ' WHERE Task_Status__c = :ready  AND Last_Completed__c != TODAY AND LeftProp_DSS__Active_Fields__c > 0';

        // below includes LIMIT 1 to ensure we return only the one most needing task
        filterClause += ' ORDER BY Task_Priority__c, Last_Completed__c  LIMIT 1 ';  

        if ( !string.isBlank(taskID) ) {
            // replace the WHERE clause when given a specific task to run and set the specifedTask flag to true
            filterClause = ' WHERE id = :taskID ';  
        }
        return q + filterClause;
    }


    global static string tuneWhereClause(string whereClause){
        if (string.isBlank(whereClause)) return null;

        list<string> capsList = new list<string>{'and', 'or', 'not', 'like', 'in', 'from', 'where', 'null', 'with', 'group by', 'order by', 'desc', 'yesterday', 'today', 'tomorrow', 'last_week', 'this_week', 'next_week', 'last_month', 'this_month', 'next_month', 'last_90_days, next_90_days', 'last_n_days', 'next_n_days', 'next_n_weeks', 'last_n_weeks', 'next_n_months', 'last_n_months', 'this_quarter, last_quarter', 'next_quarter', 'next_n_quarters', 'last_n_quarters', 'this_year', 'last_year', 'next_year', 'next_n_years', 'last_n_years', 'this_fiscal_quarter', 'last_fiscal_quarter', 'next_fiscal_quarter', 'next_n_fiscal_quarters', 'last_n_fiscal_quarters', 'this_fiscal_year', 'last_fiscal_year', 'next_fiscal_year', 'next_n_fiscal_years', 'last_n_fiscal_years'};
        
        set<string> badQuotes = new set<string> { '’','‘','`','"','“','‟','”','’','’','〝','〞' };
        
        string tuned = '';
        list<string> words = new list<string>();
        for (string word : whereClause.trim().split(spaceStr)) {
            if (word == 'where') continue;  // remove all instances of 'where'
            if ( capsList.contains(word.toLowerCase()) ) words.add(word.toUpperCase());
            else words.add(word);
        }
        for (string word : words) tuned += word + spaceStr;

        for (string bad : badQuotes ) tuned = tuned.replace(bad, '\'');  // remove all forms of bad quotes
        return tuned.trim(); 
    }


    global string genQueryNullString(Data_Summary_Field__c f){
        if (f == null || string.isBlank(f.target_field__c)) return '';
        string nil = 'null';
        string zero = '0';
        string blank = '\'\'';
        string notEq = ' != ';

        string base = f.target_field__c + notEq ;
        string nulling = base + nil;

        if ( string.isNotEmpty(f.How_to_Null__c) || test.isRunningTest() ){
            if (f.How_to_Null__c == 'zero') nulling = + parenOpen + nulling + andStr + base + zero + parenClose;
            if (f.How_to_Null__c == 'blank') nulling = parenOpen + nulling + andStr + base + blank + parenClose;
        }
        return nulling;
    }
    
    
    global static void resetToday(){
        list<Data_Summary__c> tasks = [SELECT id FROM Data_Summary__c WHERE task_status__c = :Ready ];   
        for (Data_Summary__c t : tasks) {
            t.Last_Started__c = null;
            t.Last_Completed__c = null;
        }
        lpTools.saveList('update', tasks, 'summaryTask.resetToday');
    }


    global static string setToString(set<string> fields){
        // converts a set of strings to a single commaStr-delimited string without any braces, ellipses, etc.
        // this approach allows us to have use one field for multiple purposes, even though it can only appear in a query once.  Say find the min value and max value of field whatever__c in the same task, while having it in the query only once.  note if it's more than once in a query salesforce throws an error.
        set<string> scrubbedFieldNames = new set<string>();

        // sets are case sensitive - below makes everything lowercase to be sure we have no dupes.
        for (string field : fields) scrubbedFieldNames.add(field.toLowerCase());  

        string fieldString = '';
        for (string field : scrubbedFieldNames) fieldString += field + commaStr;
        fieldString = fieldString.removeEnd(commaStr);
        return fieldString;
    }


    global object getNull(Data_Summary_Field__c f){
        object nulling = null;
        if ( !string.isBlank(f.How_to_Null__c) ){
            if (f.How_to_Null__c == 'zero') nulling = 0;
            if (f.How_to_Null__c == 'blank') nulling = '';
        }
        return nulling;
    }


    global static RelInfo genRelInfo(string parent, string child){  
        // returns the Child Relationship Name
        RelInfo ri = new RelInfo();
        if (parent == null || child == null ) return ri;

        Schema.SObjectType parentObj = Schema.getGlobalDescribe().get(parent) ;
        Schema.SObjectType childObj = Schema.getGlobalDescribe().get(child) ;

        string crn = null;
        for (Schema.ChildRelationship rel : parentObj.getDescribe().getChildRelationships() ) {
            if (rel.getChildSObject() == childObj) {
                ri.rel = rel.getField().getDescribe().getName();
                ri.crn = rel.getRelationshipName();
                break;
            }
        }
        return ri;
    }


    // below are un-needed methods the system won't let go of since we're dealing with a managed package

    global string genQueryTimeString(){
        return null;
    }
    global string genHistoricQueryDates(){
        return null;
    }
    global date genSnapshotTimestamp(){
        return today;
    }
    global boolean runToday(Data_Summary__c ds){
        return false;
    }     
    global map<string, Data_Summary_Field__c> loadParentFieldSpecs(Data_Summary__c ds) {
        return null;
    }
    global date lastDayOfMonth(date mo){  
        return today;
    }
    global date lastDayOfPrevMonth(date mo){  
        return today;
    }
    global static RelInfo getRelInfo(string parent, string child){  
        return null;
    }
    global string genFilterQuery(){
        return null;
    }

    global string genEchoModeQuery(Data_Summary__c ds){
        // this produces the summary query when running in echo mode
        // note that it REPLACES the standard parentQuery

        // // uses the set to make sure no field is added to the query more than once
        // set<string> fieldNames = new set<string>{'id'};       
        // for (Data_Summary_Field__c dsf : fieldSpecs.values() ){
        //     if ( !string.isBlank(dsf.Source_Field__c)) { 
        //         fieldNames.add(dsf.Source_Field__c);  
        //     }
        // }     

        // parentQuery = 'SELECT ' + setToString(fieldNames);
        // parentQuery += ' FROM ' +  ds.Parent_Object__c;
        // if ( !string.isblank(whereClause)) parentQuery += ' ' + whereClause;
        // return parentQuery;
        return null;
    }
}