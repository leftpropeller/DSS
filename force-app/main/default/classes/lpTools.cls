/*
 *  Steve Berley - steve@leftpropeller.com
 */ 
public with sharing class lpTools {
	private static boolean alreadyRan = false;
	private static integer runCount = 0;

    private static integer maxReport{
        get{
            if(maxReport == null || maxReport == 0){
                maxReport = errlog__c.report__c.getDescribe().getLength();
            }
            return maxReport;
        } set;
    }

    
    public static integer fyStartMonth{
        get {
            if (fyStartMonth == null || fyStartMonth == 0) {
                fyStartMonth = [SELECT FiscalYearStartMonth FROM Organization].FiscalYearStartMonth;
            }
            return fyStartMonth;
        } set;
    }
    
	
	public static Boolean runningInSandbox{
		get{
			if (runningInSandbox == null) {
				runningInSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
			}
			return runningInSandbox;
		} set;
	}


	public static integer runCounter(){
	    runCount++;
		return runCount;
    }


	public static boolean ranOnce(){
	    if ( !alreadyRan) {
	        alreadyRan = true;
	        return false;
		} else return alreadyRan;
    }


	// getters and setters above/methods below
	
	public static date endOfMonth(date d){
		if (d == null) return null;
		date eom = date.newInstance(d.year(), d.month(), 1);
		eom = eom.addMonths(1).addDays(-1);
		return eom;
	}


	public static string genQuery(string objName){
        string q = 'select ';
        for (string f : Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().keyset() ) q += f +', ';
        q = q.substringBeforeLast(','); 
        q += '  from ' + objName ;
        return q;
	}
	

	public static String getSObjectName(id i){
		return i.getSObjectType().getDescribe().getName();
	}
	
    
    public static sObject genObjectRecord(string objName, string i ){
        sObject so = Schema.getGlobalDescribe().get(objName).newSObject();
        if (i != null && i != '') so.put('id', id.valueOf(i));
        return so;
    }


	public static string javaDateFormat(date d){
		if(d == null) return '';
		string j = string.valueOf(d.year()) + '-';
		j += ('00' + string.valueOf(d.month())).right(2) + '-';
		j += ('00' + string.valueOf(d.day())).right(2);
		return j;
	}
	
	
	public static void saveRec(string command, sobject obj, string caller){
		if ( obj == null ) return;
		list<sobject> objList = new list<SObject>();
		objList.add(obj);
		saveList(command, objList, caller);
	}


	public static void saveList(string command, list<sobject> objList, string caller){
		if ( string.isBlank(command) || objList == null || objList.size() == 0 ) return;

        Schema.DescribeSObjectResult objDesc = objList[0].getSObjectType().getDescribe();

		try {
			if (command == 'insert' && objDesc.isCreateable() ) insert objlist;
			else if (command == 'update' && objDesc.isUpdateable() ) update objlist;
			else if (command == 'upsert' && objDesc.isCreateable() && objDesc.isUpdateable() ) upsert objlist;
			else if (command == 'delete' && objDesc.isDeletable() ) delete objlist;
		} catch (exception e){
			logError(caller, e);
		}
	}


	public static void logError(string caller, exception e){
		insert new ErrLog__c(caller__c = caller, report__c = makeReport(e));
	}


	public static list<sobject> queryAllFields(string objName, string predicate) {
        if (predicate == null) predicate = '';
        Map <String, Schema.SObjectField> fieldlist = Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap();

        string query = '';
        for (string f : fieldlist.keyset() ) {
            query += (query == '' ? '' : ', ' ) + f;
        }
        query = 'select ' + query + ' from ' + objName + ' ' + predicate;
        return Database.query(query);
    }


	public static map<id, sobject> queryAllFieldsToMap(string objName, string predicate) {
        list<sobject> result = queryAllFields( objName,  predicate);
        map<id, sobject> out = new map<id, sobject>();
        for (sobject r : result) out.put(r.id, r);
        return out;
    }



	public static string getFieldType(string obj, string field){
		string ret = '';
		if (string.isblank(obj) || string.isblank(field)) return ret;
		Map<String, Schema.SObjectType> objects = Schema.getGlobalDescribe(); 
		if ( !objects.containsKey(obj) ) ret = 'Object does not exist: ' + obj.toLowerCase().capitalize();
		else {
			map<string, Schema.SObjectField> fields = objects.get(obj).getDescribe().fields.getMap();
			if ( !fields.containsKey(field)) ret = field.toLowerCase().capitalize() + ' not found in '+ obj.toLowerCase().capitalize() + ' object.';
			else {
				Schema.DisplayType describe = fields.get(field).getDescribe().getType();
				ret = string.valueOf( describe ).toLowerCase().capitalize() ;
			}
		}
		return ret;
	}


	public static string makeReport(exception e){
		if (e == null) return ''; 
		string br = '\n';
		string msg;
		// msg = '---------------------------------------------------------------'+br;
	    msg = e + br + br;
	    msg += 'Error Type: ' + e.getTypeName() + br;
	    msg += 'Cause: ' + e.getCause() + br;
	    msg += 'Line: ' + string.valueof(e.getLineNumber()) + br;

	    if (e.getTypeName() == 'System.DmlException' || e.getTypeName() == 'System.EmailException') {
	        msg += '# Failed Rows: ' + e.getNumDml() + br;
	        for(integer i = 0; i < e.getNumDML(); i++){
	    	    msg += '-  Rows: ' + string.valueof(i) + br;
	    	    msg += '-  Field: ' + e.getDmlIndex(i) + br;
	    	    msg += '-  Error: ' + e.getDMLMessage(i) + br;
	    	    msg += '-  Status Code: ' + e.getDmlStatusCode(i) + br;
	        }
	        msg += br;
	    }
	    msg += br + br+ br;
        if (msg.length() > maxReport) msg = msg.abbreviate(maxReport); // keeps it from overrunning the field 
		return msg;
	}
}