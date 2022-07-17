/*
*  Steve Berley - steve@leftpropeller.com
*
*  IMPORTANT:  The challenge when creating data for testing is to use factory fields provided with core Salesforce.  This means none
*  that end in __c.  Doing so will make the code easier to move between orgs since you don't have to worry about whether fields exist.
*
*/
@isTest 
public class DataSummaries_test {
    public static string snapObj = 'asset';

    @isTest static void test_one(){
        // tests: echo, sum
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'name', 'name', 'copy') );
        fields.add( genField(ds.id, 'amount', 'quantity', 'sum') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_one');
        
        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }


    @isTest static void test_two(){
        // tests: echo, average
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'name', 'name', 'copy') );
        fields.add( genField(ds.id, 'amount', 'quantity', 'average') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_two');

        test.startTest();
           DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }



    @isTest static void test_three(){
        // tests: oldest and count
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'name', 'name', 'oldest value') );
        fields.add( genField(ds.id, 'amount', 'quantity', 'count') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_three');

        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }


    @isTest static void test_count(){
        // tests:  count
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'amount', 'quantity', 'count') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_count');

        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }


    @isTest static void test_uniques(){
        // tests:  count
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'name', 'quantity', 'count unique values (ignore case)' ) );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_uniques');

        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    } 


    @isTest static void test_median(){
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'name', 'name', 'copy') );
        fields.add( genField(ds.id, 'amount', 'quantity', 'median') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_median');

        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }

    
    @isTest static void test_oldest(){
        // tests: oldest 
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'name', 'name', 'oldest value') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_oldest');

        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }


    @isTest static void test_newest(){
        // tests: newest 
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'name', 'name', 'newest value') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_newest');

        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }


    @isTest static void test_max(){
        // tests: max
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'amount', 'quantity', 'max') );
        // fields.add( genField(ds.id, 'closedate', 'installdate', 'newest value') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_max');

        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }


    @isTest static void test_min(){
        // tests: min
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'amount', 'quantity', 'min') );
        // fields.add( genField(ds.id, 'closedate', 'installdate', 'newest value') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_min');

        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }
    

    @isTest static void test_stdDev(){
        // tests: just tests standard deviations
        createData();
        Data_Summary__c ds = createSummaryObj(snapObj);

        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'amount', 'quantity', 'standard deviation (sample)') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_stdDev');

        test.startTest();
            DataSummaries.startNow(new summaryTask(ds.id));
        test.stopTest();
    }

    
    // @isTest static void test_setValue(){
    //     // tests: set value
    //     createData();
    //     Data_Summary__c ds = createSummaryObj(snapObj);
    //     list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
    //     Data_Summary_Field__c stamper = genField(ds.id, 'name', 'name', 'set specific value');
    //     stamper.Specific_Value_to_Set__c = 'hello sweetie';
    //     fields.add( stamper );
    //     insert fields;

    //     verifyConfigDataSetup(ds.id, 'test_setValue');

    //     test.startTest();
    //         DataSummaries.startNow(new summaryTask(ds.id));
    //     test.stopTest();
    // }


    @isTest static void test_clearFields(){
        Data_Summary__c ds = createSummaryObj(snapObj);
        list<Data_Summary_Field__c> fields = new list<Data_Summary_Field__c>();
        fields.add( genField(ds.id, 'name', 'name', 'copy') );
        fields.add( genField(ds.id, 'amount', 'quantity', 'sum') );
        // fields.add( genField(ds.id, 'closedate', 'installdate', 'min') );
        insert fields;
        verifyConfigDataSetup(ds.id, 'test_clearFields');

        list<Opportunity> opps = createData();

        // create a snapshot record that gets queried below
        account a = new account(name='test');
        insert a;
        sObject snapRec = lpTools.genObjectRecord(snapObj, null);
        snapRec.put('accountID', a.id);
        snapRec.put('name', 'name');
        insert snapRec;

        summaryTask st = new summaryTask(ds.id);
        st.pass = summaryTask.pass2;

        test.startTest();
            DataSummaries dsTask = new DataSummaries(st);
            for (SObject so : database.query('select id from asset')) {
                dsTask.clearOutTargetFields(so);
                for (Data_Summary_Field__c f : st.fieldSpecs.values()){
                    // dsTask.clearoutfield(so, f.source_field__c);
                }
            }
        test.stopTest();     
    }

    
    public static void verifyConfigDataSetup(id summaryID, string test){
        summaryTask st = new summaryTask(summaryID);
        system.assert( !string.isblank(st.parentQuery), '>>>>>>    config data load failure!!!  '+test  );
    }


    public static list<opportunity> createData(){
        account a = new account(name='test account');
        insert a;
        date yesterday = date.today().addDays(-1);

        list<opportunity> opps = new list<opportunity>();
        opps.add( new opportunity(accountid = a.id, amount = 12.34, name='xx', closedate=yesterday,stagename='closed won'));
        opps.add( new opportunity(accountid = a.id, amount = 22.34, name='xx', closedate=yesterday,stagename='closed won'));
        opps.add( new opportunity(accountid = a.id, amount = 33.34, name='xx', closedate=date.newInstance(1966,9,26),stagename='closed won'));
        opps.add( new opportunity(accountid = a.id, amount = 44.34, name='xx', closedate=date.today(),stagename='closed won'));
        insert opps;
        
        summaryTask st = new summaryTask(null);
        insert new asset(name = 'aa', accountid = a.id, installdate = st.snapdate);
        return opps;
    }


    public static Data_Summary_Field__c genField(id summary, string source, string target, string action){
        return new Data_Summary_Field__c(summary__c = summary, Source_Field__c = source, target_field__c = target, How_to_Summarize__c = action);
    }


    public static Data_Summary__c createSummaryObj(string snapObj){
        Data_Summary__c ds = new Data_Summary__c();
        ds.Description__c = 'data summary for testing';
        ds.Parent_Object__c = 'Account';
        ds.Frequency__c = 'Daily - Previous';
        ds.Child_Object__c = 'Opportunity';
        ds.Date_Field_on_Child_Record__c = 'closedate';
        if ( string.isNotBlank(snapObj) ) {
            ds.Snapshot_Object__c = snapObj;
            ds.Snapshot_Date_Field__c = 'PurchaseDate';
        }
        insert ds;
        return ds;
    }
}