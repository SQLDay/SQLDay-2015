USE tSQLt_Example
GO


EXECUTE tSQLt.RenameClass 
	@SchemaName ='[First test class]',
	@NewSchemaName = '[New test class]'
GO