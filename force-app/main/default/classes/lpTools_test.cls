/*
 *  Steve Berley - steve@leftpropeller.com
 */ 
@isTest
public with sharing class lpTools_test {
    // public lpTools_test() {    }


    @isTest static void test_genQuery(){
        lpTools.genQuery('account');
    }


    @isTest static void test_getObjName(){
        account a = new account(name='test');
        insert a;
        lpTools.getSObjectName(a.id);
    }


    @isTest static void test_queryAllFields(){
        insert new account(name='test');
        lpTools.queryAllFields('account', 'where name != null');
        lpTools.queryAllFieldsToMap('account', 'where name != null');
    }


    @isTest static void test_getters(){
        integer fy = lpTools.fyStartMonth;  
        boolean sand = lpTools.runningInSandbox;
        integer x = lpTools.runCounter(); 
    }


    @isTest static void test_endOfMonth(){
        lpTools.endOfMonth(date.today());
    }   


    @isTest static void test_ranOnce(){
        boolean ran = lpTools.ranOnce();
        ran = lpTools.ranOnce();
    }


    @isTest static void test_genNewRecord(){
        account a = new account(name='test');
        insert a;
        lpTools.genObjectRecord('account', a.id);
    }


    @isTest static void test_getFieldType(){
        lpTools.getFieldType('account', 'name');
    }


    @isTest static void test_javaDateFormat(){
        lpTools.javaDateFormat(date.today());
    }


    @isTest static void test_saveRec_with_Error() {
        lptools.saveRec('update', new lead(), 'lpTools - test_saveRec_with_Error');
    }
    
    @isTest static void test_saveList_and_saveSet() {
        list<lead> ll = new list<lead>();
        ll.add(new lead(lastName = 'lastname ', company='company '));
        lptools.saveList('insert', ll,'test_saveList_and_saveSet');
        lpTools.saveList('update', ll, 'test_saveList_and_saveSet');

        for (lead l : ll) {
            l.lastName += ' 1';
            l.company += ' 1';
        }
        lptools.saveList('update', ll,'test_saveList_and_saveSet - list');
    
        for (lead l : ll) {
            l.lastName += '2';
            l.company += '2';
        }
        ll.add(new lead(lastName = 'lastname 47', company='company 47'));
    
        lptools.saveList('upsert', ll,'test_saveList');
        lptools.saveList('dog', ll,'test_saveList');
        lptools.saveList('delete', ll,'test_saveList');
    }

    @isTest static void checkNumeric_test() {
        lptools.checkNumeric('-1,234.567');
    }
}
