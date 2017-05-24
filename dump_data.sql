CREATE OR REPLACE PACKAGE  "DUMP_DATA" as
/*
  Dump rows of query or cursor to the console.
  
  Based on the example from Oracle documentation:
    https://docs.oracle.com/cd/B28359_01/appdev.111/b28370/dynamic.htm#BHCHJBHJ
  2017-05-24 miktim@mail.ru
*/

Type ref_cursor IS REF CURSOR;

procedure query 
( p_query in varchar2               -- query without trailing ';' 
, p_rows  in pls_integer default -1 -- rows to output (all)
, p_width in pls_integer default 50 -- output width of field values (-1 = as is) 
);
procedure refcursor 
( p_cursor in out ref_cursor
, p_rows   in pls_integer default -1 
, p_width  in pls_integer default 50
);
/* Usage:
declare
  l_cursor dump_data.ref_cursor;
  l_object_type varchar2(100) := 'PROCEDURE';
begin
  dump_data.query('select * from user_objects where object_type = '''
    ||l_object_type||'''', 5, 5);
  open l_cursor for select * from user_objects where object_type = l_object_type;
  dump_data.refcursor(l_cursor);
exception
  when others then
    dbms_output.put_line ( DBMS_UTILITY.FORMAT_ERROR_STACK() );
    dbms_output.put_line ( DBMS_UTILITY.FORMAT_ERROR_BACKTRACE() );
end;
*/
end;
/
CREATE OR REPLACE PACKAGE BODY  "DUMP_DATA" is
procedure refcursor
( p_cursor in out ref_cursor
, p_rows   in pls_integer default -1 
, p_width  in pls_integer default 50  
)
is
  curid   NUMBER;
  desctab DBMS_SQL.DESC_TAB;
  colcnt  NUMBER;
  namevar VARCHAR2(32767);
  outline VARCHAR2(32767);
  
  l_rows  pls_integer := p_rows;
  l_width pls_integer := case when p_width <= 0 then 32767 else p_width end;BEGIN
  -- Switch from native dynamic SQL to DBMS_SQL package:
  curid := DBMS_SQL.TO_CURSOR_NUMBER(p_cursor);
  DBMS_SQL.DESCRIBE_COLUMNS(curid, colcnt, desctab);
  -- Define columns:
  FOR i IN 1 .. colcnt LOOP
    if desctab(i).col_type 
-- Any data type, that is implicitly converted to VARCHAR2
      in ( 2, 100, 101, 12, 178, 179, 180, 181 , 231, 1, 8, 9, 96, 112 )
    then
      DBMS_SQL.DEFINE_COLUMN(curid, i, namevar, 32767);
    end if;
    outline := outline || desctab(i).col_name 
      || case when i < colcnt then ' | ' else '' end;  END LOOP;
  dbms_output.put_line(outline);
  -- Fetch rows with DBMS_SQL package:
  WHILE DBMS_SQL.FETCH_ROWS(curid) > 0 LOOP    EXIT WHEN l_rows = 0;
    outline := '';    FOR i IN 1 .. colcnt LOOP
      begin
        DBMS_SQL.COLUMN_VALUE(curid, i, namevar);
      exception when others then
        namevar := '[datatype'||desctab(i).col_type||']';      end; 
      outline := outline 
        || case 
             when length(namevar) > l_width then substr(namevar,1,l_width) || '>'
             else namevar || ' ' end
        || case when i < colcnt then '| ' else '' end;    END LOOP;
    dbms_output.put_line(outline);
    l_rows := l_rows - 1;
  END LOOP;
  if l_rows = 0 then
    dbms_output.put_line('More than '|| p_rows ||' rows available.');  end if;
  DBMS_SQL.CLOSE_CURSOR(curid);
END;

procedure query 
( p_query in varchar2 
, p_rows  in pls_integer default -1 
, p_width in pls_integer default 50  
)
is
  src_cur  ref_cursor;
begin
  -- Open REF CURSOR variable:
  OPEN src_cur FOR p_query;
  refcursor(src_cur, p_rows, p_width);
--  CLOSE src_cur;
end;

end "DUMP_DATA";
/
