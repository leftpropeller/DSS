/*
*  Steve Berley - steve@leftpropeller.com
*  This class provides the job control for Data Summaries and Snapshots while DataSummaries does the actual work.  
*  System iteratively goes through the records in the Data_Summary__c object running each applicable one as it's own 
*  batch job.  "Applicable" means - Active = true and the current day matches frequency requirement.
*/
public class summaryTask implements Schedulable {
    private static final string space = ' ';
    private static final string comma =  ',' + space;
    public boolean testMode = test.isRunningTest();

    // public static final string pass0 = '0-Cleanout';
    public static final string pass1 = '1-Summary';
    public static final string pass2 = '2-Outliers';
    private static final string timeframeDaily = 'daily';
    private static final string timeframeWeekly = 'weekly';
    private static final string timeframeMonthly = 'monthly';
    private static final string timeframeQuarterly = 'quarterly';
    private static final string timeframeYearly = 'yearly';
    private static final string timeframeFY = 'fy';
    private static final string ready = 'Ready';
    private static final date today = date.today();

    public id taskID; 
    public string name;

    // parentQuery pulls all parent records that are relevant to the task at hand
    public string parentQuery;
    
    // childQuery pulls all child records which are to be analyzed and summarized 
    public string childQuery;

    // snapQuery pulls all existing snapshot records that are relevant to the task
    public string snapQuery;

    // outliersQuery pulls all existing snapshot records in the timeframe that have been created in the past but are no longer releveant (likely because the underlying data changed) and need the target fields cleared out.
    public string outliersQuery;

    public string parentObj;
    public string childObj;
    public string snapObj;
    public string crn;
    public string childRecDateField;
    public string frequency;
    public date snapDate;
    public string snapDateField;
    public string relFieldChild;  
    public string relFieldSnap;  
    public string whereClause;
    public integer batchSize = 50;
    public string pass;
    public boolean runSnapshots = false;
    public boolean EchoMode;
    public boolean runningSpecifiedTask = false;
    public boolean specifiedSnapDate = false;
    public boolean currentTimePeriod = true;  // ex: current month vs previous month
    public map<string, Data_Summary_Field__c> fieldSpecs;   // map<field on source object, field details record>


    public summaryTask(id param1) {
        if ( !string.isblank(param1)) {
            runningSpecifiedTask = true;
            loadNextSummaryTask(param1);
        }
        else if ( string.isBlank(pass) ) {
            pass = pass1;
            loadNextSummaryTask(null);
        }
    }


    public class RelInfo{
        public string rel;
        public string crn;
    }

    
    public void execute(SchedulableContext SC) {
        // looks for a task to run and start the first one that's found.
        loadNextSummaryTask(null);
        // startDataSummaries();
    }


    public static void start(integer hr, integer min){
        if (hr == null) hr = -1;
        summaryTask st = new summaryTask(null);

        if (hr == -1) st.loadNextSummaryTask(null);  // start now
        else {
            if (min == null) min = 47;
            string job = 'Data Summary Tasks ' + dateTime.now().format();
            string cron = '0 ' + string.valueOf(min) + ' ' + string.valueOf(hr) + ' * * ?';
            system.schedule(job, cron, st);
        }
    }


    public static void startNow(){
        // Wrapper method to limit external dependencies as this code evolves.
        summaryTask.start(-1,0);
    }

    
    @invocableMethod (label='Start a Data Summary Task (summaryTask)')
    public static list<boolean> SummaryTaskInvocable(list<string> tasks){
        string pipe = '|';
        string colon = ':';
        // to call this from a flow - pass {!recordID} as the parameter
        if ( tasks != null && tasks.size() > 0) {
            for (string task : tasks){
                string taskID = task.substringBefore(pipe);
                string timeToSchedule = task.substringAfter(pipe);
                if ( !string.isBlank(taskID)){
                    summaryTask st = new summaryTask( taskID );
                }
                if( !string.isBlank(timeToSchedule) ){
                    integer hr = integer.valueOf(timeToSchedule.substringBefore(colon));
                    integer min = integer.valueOf(timeToSchedule.substringAfter(colon));
                    if (min == null) min = 0;
                    summaryTask.start(hr, min);
                }
            }
        }
        return isScheduled();
    }
    

    public void endTask(){
        if (taskID == null) return;
        Data_Summary__c t = new Data_Summary__c (id=taskID, Last_Completed__c=datetime.now());
        lpTools.saveRec('update', t, 'summaryTask.completedTask');
    }
    
    
    public void startTask(){
        if (taskID == null) return;
        Data_Summary__c t = new Data_Summary__c (id=taskID, Last_Started__c=datetime.now());
        lpTools.saveRec('update', t, 'summaryTask.completedTask');
    }


    public static list<boolean> isScheduled(){
        boolean scheduled = false;
        list<AsyncApexJob> jobs = [SELECT id FROM AsyncApexJob WHERE JobType = 'ScheduledApex' AND Status = 'Queued' AND ApexClass.Name IN ('summarytask', 'LeftProp_DSS.summaryTask', 'dssTaskManager', 'LeftProp_DSS.dssTaskManager')];
        if (jobs != null && jobs.size() > 0) scheduled = true;
        return new list<boolean>{scheduled};
    }


    public void startDataSummaries(){
        startTask();  // set the timestamp for starting the task
        if ( this != null && !string.isBlank(parentObj) && !string.isBlank(childObj) ) {
            // if both the st.parent and st.child objects are not blank there's a task to run, so call DataSummaries to do it.
            database.executeBatch(new DataSummaries(this), batchSize);
        }
    }


    public summaryTask loadNextSummaryTask(id param1){
        taskID = null;
        if ( !string.isBlank(param1) ) taskID = param1;

        Data_Summary__c ds;
        boolean found = false;
        for (Data_Summary__c summary : database.query(genTaskQuery(taskID))){
            if ( runningSpecifiedTask || runToday(summary) ) {
                // if we're running a specific task and the task is due to be run today, stop and do it.
                found = true;
                ds = summary;
                break;
            }
        }
        if (!found) return null;  // if not tasks found - bail out

        // populate instance variables based on the found task 
        if ( string.isBlank(taskID) ) taskID = ds.id;
        name = ds.name;
        parentObj = ds.Parent_Object__c;
        childObj = ds.Child_Object__c;
        if  ( ds.Snapshot_Object__c != null ) {
            snapObj = ds.Snapshot_Object__c;
            runSnapshots = true;
        }
        crn = ds.Child_Relationship_Name__c;
        relFieldChild = ds.Relationship_Field_Child__c;
        if ( !string.isBlank(ds.Relationship_Field_Snapshot__c)) relFieldSnap = ds.Relationship_Field_Snapshot__c;
        if  ( !string.isBlank(ds.Date_Field_on_Child_Record__c) ) childRecDateField = ds.Date_Field_on_Child_Record__c;

        if (ds.Where_Clause__c != null) whereClause =  ' WHERE ' + ds.Where_Clause__c ;

        if ( !string.isBlank(ds.Snapshot_Date_Field__c) ) snapDateField = ds.Snapshot_Date_Field__c;

        if (!string.isBlank(ds.Frequency__c) ) {
            frequency = ds.frequency__c.tolowercase();
            if (frequency.contains('prev') || frequency.contains('last')) currentTimePeriod = false;
        }

        snapDate = today;
        if (ds.Snapshot_As_Of_Date__c != null) {
            specifiedSnapDate = true;
            snapDate = ds.Snapshot_As_Of_Date__c;
            if ( !string.isBlank(frequency) && frequency.toLowerCase().contains('month')) {
                // if frequency is monthly this forces the snap date to be the end of the month
                snapDate = lpTools.endOfMonth(snapDate);  
            }
        }
        else snapDate =  genSnapshotTimestamp();

        fieldSpecs = loadParentFieldSpecs(ds);

        genSnapQuery(ds);
        if ( ds.batch_size__c != null && ds.batch_size__c > 0) batchSize = (integer) ds.batch_size__c;

        genparentQuery();

        EchoMode = false;
        if (ds.Echo_Mode__c) {
            EchoMode = true;
            genEchoModeQuery(ds);
        }
        genChildQuery();
        genOutliersQuery();
    
        startDataSummaries();
        return this;
    }
     
    
    public boolean runToday(Data_Summary__c ds){
        if (string.isblank(ds.Frequency__c)) return false;
        boolean run = false;
        date d = today;
        if (test.isRunningTest()) d = date.newInstance(2017, 1, 1);  // Note:  Jan 1, 2017 was a Sunday


        string freq = ds.Frequency__c.tolowercase();
        if ( !run && string.isNotBlank(ds.Process_Data__c) && ds.Process_Data__c.toLowerCase() == 'daily' ) run = true;

        if (!run && (freq.contains('day') || freq.contains('daily')) ) run = true;

        if (!run && freq.contains('fy') 
                && d.day() == 1 && d.month() == fyStartMonth ) run = true;

        if (!run && freq.contains('quarter') 
                && d.day() == 1 && math.mod(d.month(), 3) == 1) run = true;

        if (!run && freq.contains('year') 
                && d.day() == 1 && d.month() == 1) run = true;

        if (!run && freq.contains('month')
                && d.day() == 1) run = true;

        if (!run && freq.contains('week')
                && datetime.newInstance(d.year(), d.month(), d.day()).format('EEEE') == 'Sunday') run = true;

        if (test.isRunningTest()) run = true;
        
        return run;
    }     

    
    public map<string, Data_Summary_Field__c> loadParentFieldSpecs(Data_Summary__c ds) {
        // loads the related Data_Summary_Field__c records in to the map fieldSpecs<field name, Data_Summary_Field__c>
        fieldSpecs = new map<string, Data_Summary_Field__c>();
        for (Data_Summary_Field__c f : ds.Data_Summary_Fields__r ){
            if ( !string.isBlank(f.target_field__c) ){
                fieldSpecs.put(f.target_field__c, f);    
            }
        }
        return fieldSpecs;
    }
    
    
    public string genparentQuery(){
        // generates the query that pulls set of relevant parent records for the summarization process.  
        // Querying the actual child records happens elsewhere.  This is done so all child records are pulled at once for a given parent.

        // uses the set to make sure no field is added to the query more than once and ensure id is always included
        set<string> fieldNames = new set<string>{'id'};       
        if ( !runSnapshots ){
            for (string field : fieldSpecs.keySet()) {
                fieldNames.add(field); 
            }
        }

        parentQuery = 'SELECT ' + setToString(fieldNames);       
        parentQuery += ' FROM ' + parentObj;

        string wherePhrase = '';
        if ( !string.isBlank(whereClause) ) {
            wherePhrase += ' ' + genFilterQuery();
            if ( !string.isBlank(wherePhrase) ) wherePhrase = ' WHERE id IN ( ' + wherePhrase + ' )';
            else if ( !string.isBlank(whereClause) ) wherePhrase =  whereClause;  // if there's no genFilterQuery, use the where clause on the parent    
        }

        if ( !string.isBlank(wherePhrase) ) parentQuery += wherePhrase;
        return parentQuery;
    }


    public string genEchoModeQuery(Data_Summary__c ds){
        // this produces the summary query when running in echo mode
        // note that it REPLACES the standard parentQuery

        // uses the set to make sure no field is added to the query more than once
        set<string> fieldNames = new set<string>{'id'};       
        for (Data_Summary_Field__c dsf : ds.Data_Summary_Fields__r){
            if ( !string.isBlank(dsf.Source_Field__c)) { 
                fieldNames.add(dsf.Source_Field__c);  
            }
        }     

        parentQuery = 'SELECT ' + setToString(fieldNames);
        parentQuery += ' FROM ' +  ds.Parent_Object__c;
        if ( !string.isblank(whereClause)) parentQuery += ' ' + whereClause;
        return parentQuery;
    }
    

    public string genSnapQuery(Data_Summary__c ds){
        // snapQuery finds the records already existing in the snapshot object.  the query result is used 
        // to prevent the creation of duplicate snapshot records for a given timeframe

        // returns:  SELECT id, target fields FROM snapObj WHERE date = snapDate

        // uses the set to make sure no field is added to the query more than once
        set<string> fieldNames = new set<string>{'id'}; 
        if ( !string.isBlank(ds.Relationship_Field_Snapshot__c)) fieldNames.add(ds.Relationship_Field_Snapshot__c);
        if ( !string.isBlank(ds.Snapshot_Date_Field__c)) fieldNames.add(ds.Snapshot_Date_Field__c);
        
        for (Data_Summary_Field__c dsf : ds.Data_Summary_Fields__r){
            if ( !string.isBlank(dsf.Target_Field__c) ) fieldNames.add(dsf.Target_Field__c); 
        }
        snapQuery = 'SELECT ' + setToString(fieldNames);
        snapQuery += ' FROM ' + ds.Snapshot_Object__c;
        snapQuery += ' WHERE ' + ds.Snapshot_Date_Field__c + ' = ' + string.valueOf(snapDate);
        return snapQuery;
    }

    
    public string genFilterQuery(){
        // the genFilterQuery limits the records to be processed to those in the correct context based on the parent object id
        // in the following: SELECT id FROM contact WHERE id IN ( SELECT Contact__c FROM Country_Visited__c WHERE date__c = THIS_MONTH )
        // the sub query inside the WHERE IN (xxx) is the filter query.
        // in the example its: SELECT Contact__c FROM Country_Visited__c WHERE date__c = THIS_MONTH

        if (relFieldChild == null || childObj == null) return ' ';
        string fq = 'SELECT ' + relFieldChild;
        fq += ' FROM ' + childObj;
        if ( !string.isBlank(whereClause) ) fq += ' ' + whereClause;
        return fq;
    }
    

    public string genChildQuery(){
        // childQuery pulls all of the relevant child records for a given set of parents.  these are the records to be analyzed

        // bail if there's not enough info to proceed, including if there are no fields specified.
        if ( (!EchoMode && (relFieldChild == null || childObj == null) ) || fieldSpecs.values().size() == 0) return null;

        // uses the set to make sure no field is added to the query more than once
        set<string> fieldNames = new set<string>{'id'};       
        if (!echoMode) fieldNames.add(relFieldChild);
        for (Data_Summary_Field__c f : fieldSpecs.values()) fieldnames.add(f.Source_Field__c);  

        string timeFilter = '';
        if ( !string.isBlank(childRecDateField) ) {
            fieldnames.add(childRecDateField); // add the child rec date field whenever possible
            if (!string.isblank(frequency)) {
                if (!specifiedSnapDate) timeFilter += ' AND ' + childRecDateField + ' = ' + genQueryTimeString();
                else timeFilter += genHistoricQueryDates();
            }
            
        }

        string cq = 'SELECT ' + setToString(fieldNames);
        if (echoMode) cq += ' FROM ' + parentObj;
        else cq += ' FROM ' + childObj;

        string parentFilter =  ' ' + relFieldChild + ' IN :parentIDs ';

        // note that the parent filter is only added below if not in echo mode.
        if ( !string.isBlank(whereClause) ) {
            cq += ' ' + whereClause ;
            if (!EchoMode) cq += ' AND ' + parentFilter;
        }
        else if (!EchoMode) cq += ' WHERE ' + parentFilter;

        // if running normally and the user didn't include the time filter to the query - add it here.
        if ( !string.isBlank(childRecDateField)) {
            // below is just about making sure whereClause doesn't contain reference to the date field. 
            if ( string.isblank(whereClause) 
                || (!string.isblank(whereClause) && !whereClause.contains(childRecDateField)) ) cq += timeFilter;
        }
        childQuery = cq;
        return childQuery;
    }


    public string genHistoricQueryDates(){
        // this method creates the part of the where clause to account for historical dates, based on the snapDate field and frequency.
        // it also sets the snapDate to the end of the period so data is recorded when expected
        if (snapDate == null || string.isblank(frequency)) return '';
        date startDate;
        date endDate;
        string historic = '';
        integer prevPeriodOffsetMonths = 0;

        if (frequency.toLowerCase().contains('day') || frequency.toLowerCase().contains('daily')) {
            // the simplicity of days makes them a special case.
            date day = snapDate;
            if (!currentTimePeriod) day = day.addDays(-1);
            historic = ' AND ' + childRecDateField + space + ' = ' + lpTools.javaDateFormat(day);
        }

        else if (frequency.toLowerCase().contains('month')) {
            startDate = date.newInstance(snapDate.year(), snapDate.month(), 1);
            endDate = startDate.addMonths(1);    
            if (!currentTimePeriod) prevPeriodOffsetMonths = -1;
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
            if (!currentTimePeriod) prevPeriodOffsetMonths = -3;
        }

        else if (frequency.toLowerCase().contains('fy')) {
            integer month = snapDate.month();
            integer year = snapDate.year();

            if (month < fyStartMonth) year--;  // implies the FY started in the previous calendar year
            startDate = date.newInstance(year, fyStartMonth, 1);
            endDate = startDate.addMonths(12);    
            if (!currentTimePeriod) prevPeriodOffsetMonths = -12;
        }

        else if (frequency.toLowerCase().contains('year')) {
            startDate = date.newInstance(snapDate.year(), 1, 1);
            endDate = startDate.addMonths(12);    
            if (!currentTimePeriod) prevPeriodOffsetMonths = -12;
        }

        if (startDate != null && endDate != null && string.isblank(historic)){
            this.snapDate = endDate.addDays(-1);  // ensures the snap date aligns with the end of the period.

            // adjust dates to accomodate the previous period
            startDate = startDate.addMonths(prevPeriodOffsetMonths);    
            endDate = endDate.addMonths(prevPeriodOffsetMonths);    

            // if historic has not yet been set...
            historic = ' AND ' + childRecDateField + space + ' >= ' + lpTools.javaDateFormat(startDate);
            historic += ' AND ' + childRecDateField + space + ' < ' +  lpTools.javaDateFormat(endDate);    
        }
        return historic;
    }


    public string genOutliersQuery(){
        // let's say you're tracking the number of opps created this month on the account record.  if a given account had some
        // created last month but none yet this month, the field would erroneously hold a value.  this generates the query
        // which identifies those "outliers" and is used to clear them out.

        string oq = '';
        for (string field : fieldSpecs.keySet()){
            Data_Summary_Field__c f = fieldSpecs.get(field);
            if (f.Target_Field__c != null) oq +=  genQueryNullString(f) + ' OR ';
        }
        if ( !string.isBlank(oq) )  oq =  '( ' + oq.trim().removeEndIgnoreCase('OR')  + ' )'; 

        if ( !string.isBlank(snapDateField) ){
            string datePhrase = this.snapDateField + ' = ' + genQueryTimeString();
            if (!string.isblank(oq)) oq = ' AND ' + oq;
            if ( !string.isBlank(datePhrase) ) oq = datePhrase + oq; 
        }

        string idField = ' id ';
        string obj = parentObj;
        if ( runSnapshots ) {
            idField = relFieldSnap;
            obj = snapObj;
        }
        if ( !string.isBlank(oq) ) oq = 'SELECT id FROM ' + obj + ' WHERE ' + oq;

        string fq = genFilterQuery();
        if ( !string.isBlank(fq) ) oq += ' AND ' + idField + ' NOT IN (' + fq + ')'; 

        outliersQuery = oq;
        return outliersQuery;
    }


    public string genTaskQuery(id taskID){
        // generates the query string used for querying tasks (data_summary_c records) to be processed
        string q = 'SELECT id, Parent_Object__c, Child_Object__c, Child_Relationship_Name__c, Last_Completed__c, Snapshot_Object__c, Name,  Snapshot_Date_Field__c, Snapshot_mode__c, Echo_Mode__c, Relationship_Field_Child__c, Frequency__c, Where_Clause__c, Process_Data__c, Delay_Months__c, Delay_Days__c, batch_size__c, Relationship_Field_Snapshot__c, Snapshot_As_Of_Date__c, Date_Field_on_Child_Record__c, ( SELECT Source_Field__c, Target_Field__c, Reset_Value_After_Snapshot__c, Target_Field_Type__c, How_to_Summarize__c, How_to_Null__c, Specific_Value_to_Set__c FROM Data_Summary_Fields__r WHERE Field_Status__c = :ready) FROM Data_Summary__c  '; 
        
        string filterClause = ' WHERE Task_Status__c = :ready  AND Last_Completed__c != TODAY ';

        if ( !string.isBlank(taskID) ) {
            // replace the WHERE clause when given a specific task to run and set the specifedTask flag to true
            filterClause = ' WHERE id = :taskID ';  
        }
        q += filterClause + ' ORDER BY Task_Priority__c, Last_Completed__c ';  
        return q;
    }


    public static string tuneWhereClause(string whereClause){
        if (string.isBlank(whereClause)) return null;

        string sp = ' ';
        list<string> capsList = new list<string>{'and', 'or', 'not', 'like', 'in', 'from', 'where', 'null', 'with', 'group by', 'order by', 'desc', 'yesterday', 'today', 'tomorrow', 'last_week', 'this_week', 'next_week', 'last_month', 'this_month', 'next_month', 'last_90_days, next_90_days', 'last_n_days', 'next_n_days', 'next_n_weeks', 'last_n_weeks', 'next_n_months', 'last_n_months', 'this_quarter, last_quarter', 'next_quarter', 'next_n_quarters', 'last_n_quarters', 'this_year', 'last_year', 'next_year', 'next_n_years', 'last_n_years', 'this_fiscal_quarter', 'last_fiscal_quarter', 'next_fiscal_quarter', 'next_n_fiscal_quarters', 'last_n_fiscal_quarters', 'this_fiscal_year', 'last_fiscal_year', 'next_fiscal_year', 'next_n_fiscal_years', 'last_n_fiscal_years'};
        
        set<string> badQuotes = new set<string> { '’','‘','`','"','“','‟','”','’','’','〝','〞' };
        
        string newWhere = '';
        list<string> words = new list<string>();
        for (string word : whereClause.trim().split(sp)) {
            if (word == 'where') continue;  // remove all instances of 'where'
            if ( capsList.contains(word.toLowerCase()) ) words.add(word.toUpperCase());
            else words.add(word);
        }
        for (string word : words) newWhere += word + sp;

        for (string bad : badQuotes ) newWhere = newWhere.replace(bad, '\'');  // remove all forms of bad quotes
        return newWhere.trim(); 
    }


    public string genQueryNullString(Data_Summary_Field__c f){
        string nil = 'null';
        string zero = '0';
        string blank = '\'\'';
        string notEq = ' != ';

        string base = f.target_field__c + notEq ;
        string nulling = base + nil;

        if ( string.isNotEmpty(f.How_to_Null__c) || test.isRunningTest() ){
            if (f.How_to_Null__c == 'zero') nulling = '( '+ nulling + ' AND ' + base + zero + ' )';
            if (f.How_to_Null__c == 'blank') nulling = '( '+ nulling + ' AND ' + base + blank + ' )';
        }
        return nulling;
    }
    

    public date genSnapshotTimestamp(){
        if (string.isblank(frequency)) return null;
        // determines the date the snapshot should be recorded on
        date ds;  // ds = date stamp
        frequency = frequency.toLowerCase();

        // daily 
        if (frequency.contains(timeframeDaily)) {
            ds = today;
            if( !currentTimePeriod) ds = today.addDays(-1);
        }

        else if (frequency.contains(timeframeMonthly)) {
            ds = lastDayOfMonth(today);
            if( !currentTimePeriod) ds = lastDayOfPrevMonth(today);
        }

        else if (frequency.contains(timeframeQuarterly)) {
            map<integer,integer> currQtrs = new map<integer,integer>{1=>3, 2=>3, 3=>3, 4=>6, 5=>6, 6=>6, 7=>9, 8=>9, 9=>9, 10=>12, 11=>12, 12=>12};
            map<integer,integer> prevQtrs = new map<integer,integer>{1=>12, 2=>12, 3=>12, 4=>3, 5=>3, 6=>3, 7=>6, 8=>6, 9=>6, 10=>9, 11=>9, 12=>9};
            integer yr = today.year();
            
            integer mo = currQtrs.get(today.month());  // the month when the current quarter ends
            
            if( !currentTimePeriod) {
                mo = prevQtrs.get(today.month());  // the month when the previous quarter ended
                if (mo == 12) yr--;    
            }
            ds = lastDayOfMonth(date.newInstance(yr, mo, 1));
        } 
        
        else if (frequency.contains(timeframeYearly)) {
            integer yr = today.year();
            if( !currentTimePeriod) yr = today.year()-1;
            ds = date.newInstance(yr, 12, 31);
        }
        
        else if (frequency.contains(timeframeFY)) {  
            integer yr = today.year();
            if (today.month() >= fyStartMonth) yr++;
            if( !currentTimePeriod) yr--; // decrement the year by one if the previous FY
            ds = date.newInstance(yr, fyStartMonth, 1).addDays(-1);
        }

        return ds;
    }


    public date lastDayOfMonth(date mo){  
        // gets last day of month by finding the first day of the following month then finding the preceeding day.
        date nextMo = mo.addMonths(1);
        return date.newInstance(nextMo.year(), nextMo.month(), 1).addDays(-1);
    }


    public date lastDayOfPrevMonth(date mo){  
        // gets last day of month by finding the first day of the following month then finding the preceeding day.
        return date.newInstance(mo.year(), mo.month(), 1).addDays(-1);
    }


    public static RelInfo genRelInfo(string parent, string child){  
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

        
    public static integer fyStartMonth{
        get {
            if (fyStartMonth == null || fyStartMonth == 0) {
                fyStartMonth = lpTools.fyStartMonth;
            }
            return fyStartMonth;
        } set;
    } 
    
    
    public static void resetToday(){
        list<Data_Summary__c> tasks = [SELECT id FROM Data_Summary__c WHERE active__c = true ];   
        for (Data_Summary__c t : tasks) {
            t.Last_Started__c = null;
            t.Last_Completed__c = null;
        }
        lpTools.saveList('update', tasks, 'summaryTask.resetToday');
    }


    public static string setToString(set<string> fields){
        // converts a set of strings to a single comma-delimited string without any braces, ellipses, etc.
        // this approach allows us to have use one field for multiple purposes, even though it can only appear in a query once.  Say find the min value and max value of field whatever__c in the same task, while having it in the query only once.  note if it's more than once in a query salesforce throws an error.
        set<string> scrubbedFieldNames = new set<string>();

        // sets are case sensitive - below makes everything lowercase to be sure we have no dupes.
        for (string field : fields) scrubbedFieldNames.add(field.toLowerCase());  

        string fieldString = '';
        for (string field : scrubbedFieldNames) fieldString += field + comma;
        fieldString = fieldString.removeEnd(comma);
        return fieldString;
    }


    public string genQueryTimeString(){
        if ( string.isBlank(this.frequency)) return null;
        // if ( string.isblank(this.snapDateField) || (string.isBlank(this.frequency) && !this.specifiedSnapDate) ) return null;
        string timeString = '';
        frequency = frequency.toLowerCase();

        if ( this.specifiedSnapDate ) timeString = string.valueOf(this.snapDate);
        else {
            if ( frequency.contains(timeframeDaily) ){
                timeString = 'TODAY';
                if( !currentTimePeriod) timeString = 'YESTERDAY';
            }
            else if ( frequency.contains(timeframeMonthly) ){
                timeString = ' THIS_MONTH ';
                if( !currentTimePeriod) timeString = 'LAST_MONTH';
            }
            else if ( frequency.contains(timeframeQuarterly) ){
                timeString = 'THIS_QUARTER';
                if( !currentTimePeriod) timeString = 'LAST_QUARTER';
            }
            else if (frequency.contains(timeframeYearly)) {
                timeString = 'THIS_YEAR';
                if( !currentTimePeriod) timeString = 'LAST_YEAR';
            }
            else if ( frequency.contains(timeframeFY) ){
                timeString = 'THIS_FISCAL_YEAR';
                if( !currentTimePeriod) timeString = 'LAST_FISCAL_YEAR';
            }
        }
        return timeString;
    }


    public object getNull(Data_Summary_Field__c f){
        object nulling = null;
        if ( !string.isBlank(f.How_to_Null__c) ){
            if (f.How_to_Null__c == 'zero') nulling = 0;
            if (f.How_to_Null__c == 'blank') nulling = '';
        }
        return nulling;
    }


    public static RelInfo getRelInfo(string parent, string child){  // add to lpTools
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
}