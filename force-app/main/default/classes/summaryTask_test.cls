//  Steve Berley - steve@leftpropeller.com
@isTest
public class summaryTask_test {
    public static set<string> frequencies = new set<string>{ 'Daily - Current', 'Daily - Previous', 'Monthly - Current', 'Monthly - Previous', 'Quarterly - Current', 'Quarterly - Previous', 'Yearly - Current', 'Yearly - Previous', 'FY - Current', 'FY - Previous' };
    

    @isTest public static void test_invocable(){
        id taskID = createSummaryObj(null);
        createSummaryPlan(taskID);
        summaryTask.SummaryTaskInvocable(new list<string>{taskID});
    }


    @isTest public static void test_monthEnds(){
        summaryTask st = new summaryTask(null);
        st.lastDayOfMonth(date.today());
        st.lastDayOfPrevMonth(date.today());
    }


    @isTest public static void test_timeframes(){
        set<id> taskIDs = new set<id>();
        for (string f : frequencies) {
            taskIDs.add(createSummaryObj(f));
        }

        for (id t : taskIDs) {
            summaryTask st = new summaryTask(t);
            st.genSnapshotTimestamp();
            st.genQueryTimeString();
        }
    }


    @isTest public static void test_relInfo(){
        summaryTask.genRelInfo('Account', 'Contact');
    }


    @isTest public static void summary_test(){
        id taskID = createSummaryObj(null);
        createSummaryPlan(taskID);
        // createSummaryPlan( createSummaryObj(null) );
 
        test.startTest();
	        summaryTask st = new summaryTask(null);
         	st.endTask();
	        st = new summaryTask(null);
         	st.endTask();
            summaryTask.resetToday();
        test.stopTest();
    }


    @isTest public static void echoMode_test(){
        id taskID = setupEchoTest();

        test.startTest();
	        summaryTask st = new summaryTask(taskID);
         	st.endTask();
	        st = new summaryTask(null);
         	st.endTask();
            summaryTask.resetToday();
        test.stopTest();
    }


    @isTest public static void nulling_test(){
        createSummaryPlan( createSummaryObj(null) );
        summaryTask st = new summaryTask(null);

        if (st.fieldSpecs == null || st.fieldSpecs.size() == 0) return;
        for (Data_Summary_Field__c dsf : st.fieldSpecs.values()) st.getNull(dsf);
    }


    @isTest public static void test_scheduledStart(){
    	summaryTask.start(10,null);  
    }


    @isTest public static void test_historicQuery(){
        summaryTask st = new summaryTask(createSummaryObj('monthly - previous'));
        st.snapDate = date.newInstance(2022, 6, 30);
        st.specifiedSnapDate = true;
        string q = st.genHistoricQueryDates();
    }


    @isTest public static void test_normalStart(){
    	summaryTask.startnow();  
    }


    @isTest public static void test_settingNewSchedule(){
        string startTime = '|1:47';
        summaryTask.SummaryTaskInvocable(new list<string>{startTime});
    }


    @isTest public static void test_resetToday(){
    	summaryTask.resetToday();    
    }


    @isTest public static void test_getRelInfo(){
        summaryTask.getRelInfo('account', 'contact');
    }


    @isTest public static void get_tuneWhereClause(){
        string w = ' where account.name = :hello and lastname = bonzo ';
    	summaryTask.tuneWhereClause(w);    
    }
    

    @isTest public static void test_fyStartMonth(){
    	integer fyStart = summaryTask.fyStartMonth;    
    }
        

    @isTest private static void test_runToday(){
        summaryTask st = new summaryTask(null);
        st.snapDateField = 'snap field';

        Data_Summary__c ds = new Data_Summary__c();
        ds.Process_Data__c = 'daily';
        st.runToday(ds);

        ds.Process_Data__c = null;
        for (string f : frequencies){
            ds.Frequency__c = f;
            st.runToday(ds);
        }
    }


    public static void createSummaryPlan(id dsID){
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        Data_Summary_Field__c one = new Data_Summary_Field__c();
        one.Summary__c = dsID;
        one.Source_Field__c = 'id';
        one.How_to_Summarize__c = 'count'; 
        one.target_field__c = 'amount';
        // one.Target_Field_Type__c = 'integer';
        one.Reset_Value_After_Snapshot__c = TRUE;
        fields.add(one);   
        
        // Data_Summary_Field__c two = new Data_Summary_Field__c();
        // two.Summary__c = dsID;
        // two.Source_Field__c = 'Amount';
        // two.How_to_Summarize__c = 'Sum'; 
        // two.target_field__c = 'Probability';
        // // two.Target_Field_Type__c = 'integer';     
        // two.Reset_Value_After_Snapshot__c = TRUE;
        // fields.add(two);
         
        Data_Summary_Field__c three = new Data_Summary_Field__c();
        three.Summary__c = dsID;
        three.Source_Field__c = 'birthdate';
        three.How_to_Summarize__c = 'min'; 
        three.target_field__c = 'closedate';
        // three.Target_Field_Type__c = 'date';        
        three.Reset_Value_After_Snapshot__c = TRUE;
        fields.add(three);

        Data_Summary_Field__c four = new Data_Summary_Field__c();
        four.Summary__c = dsID;
        four.Source_Field__c = 'birthdate';
        four.How_to_Summarize__c = 'max'; 
        four.target_field__c = 'closedate';
        // four.Target_Field_Type__c = 'date';        
        four.Reset_Value_After_Snapshot__c = TRUE;
        fields.add(four);
        
        Data_Summary_Field__c five = new Data_Summary_Field__c();
        five.Summary__c = dsID;
        five.Source_Field__c = 'name';
        five.How_to_Summarize__c = 'copy (including blanks)'; 
        five.target_field__c = 'name';
        // five.Target_Field_Type__c = 'string';        
        fields.add(five);

        insert fields;
    }
    
    public static id createSummaryObj(string freq){
        Data_Summary__c ds = new Data_Summary__c();
        ds.Parent_Object__c = 'Account';
        ds.Child_Object__c = 'Contact';
        ds.Child_Relationship_Name__c = 'Contacts';
        ds.Relationship_Field_Child__c = 'AccountID';
        ds.Frequency__c = 'FY - Current';
        if ( !string.isblank(freq) ) ds.frequency__c = freq;
        ds.Date_Field_on_Child_Record__c = 'Birthdate';
        ds.Snapshot_Object__c = 'Opportunity';
        ds.Snapshot_Date_Field__c = 'closedate';
        ds.where_clause__c = 'lastname != null';
        ds.active__c = true;
        insert ds;
        return ds.id;
    }
    
    public static id getRecordTypeID(string obj, string name){
		id ret = null;
		for (RecordType rt : [select id, sObjectType, name from recordtype]){
			if (rt.sObjectType == obj && rt.name == name) {
				ret = rt.id;
				break;
			}
		}
		return ret;
    }

    public static id setupEchoTest(){
        Data_Summary__c ds = new Data_Summary__c();
        ds.Description__c = 'test';
        ds.Parent_Object__c = 'Account';
        ds.Frequency__c = 'Daily - Current';
        ds.Snapshot_Object__c = 'opportunity';
        ds.Snapshot_Date_Field__c = 'closedate';
        ds.where_clause__c = 'id != null';
        ds.Snapshot_As_Of_Date__c = date.today();
        ds.active__c = true;
        insert ds;
         
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        Data_Summary_Field__c one = new Data_Summary_Field__c();
        one.Summary__c = ds.id;
        one.Source_Field__c = 'name';
        one.target_field__c = 'name';
        fields.add(one);   
        insert fields;

        return ds.id;
    }
}