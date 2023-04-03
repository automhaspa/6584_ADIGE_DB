SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW	[AwmConfigConfig].[vFieldsData]
AS SELECT fd.hash, fd.entityTypeName, fd.fieldName, fd.resourceName, fd.htmlTag, fd.filterTypeName, fd.displayOrder, fd.observe, fd.orderByIndex, fd.orderByDirection FROM AwmConfig.FieldsData fd
GO
