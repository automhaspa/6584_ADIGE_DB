CREATE TABLE [AwmConfig].[FieldsData]
(
[hash] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[entityTypeName] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[fieldName] [varchar] (100) COLLATE Latin1_General_CI_AS NOT NULL CONSTRAINT [DF__FieldsDat__field__0E44D4E4] DEFAULT (''),
[resourceName] [nvarchar] (4000) COLLATE Latin1_General_CI_AS NOT NULL CONSTRAINT [DF__FieldsDat__resou__102D1D56] DEFAULT (''),
[htmlTag] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL,
[filterTypeName] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[displayOrder] [int] NULL,
[observe] [bit] NULL,
[Icona] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[orderByIndex] [int] NULL,
[orderByDirection] [varchar] (1) COLLATE Latin1_General_CI_AS NULL,
[exportExcel] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[FieldsData] ADD CONSTRAINT [PK_dbo.FieldsData] PRIMARY KEY CLUSTERED ([entityTypeName], [fieldName]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[FieldsData] ADD CONSTRAINT [FK_FieldsData_entityType] FOREIGN KEY ([entityTypeName], [hash]) REFERENCES [AwmConfig].[entityType] ([entityTypeName], [hash]) ON UPDATE CASCADE
GO
ALTER TABLE [AwmConfig].[FieldsData] ADD CONSTRAINT [FK_FieldsData_FilterType] FOREIGN KEY ([filterTypeName]) REFERENCES [AwmConfig].[FilterType] ([filterTypeName]) ON DELETE CASCADE ON UPDATE CASCADE
GO
