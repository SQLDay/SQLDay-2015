use CustomerManagement
go

create procedure [Assertions].[test Fail]
as
begin

	exec tSQLt.Fail 'Assertion failed!'

end