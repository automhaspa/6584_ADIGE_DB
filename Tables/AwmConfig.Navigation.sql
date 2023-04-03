CREATE TABLE [AwmConfig].[Navigation]
(
[NavigationKey] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[entityTypeNameSource] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[hashSource] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[fieldNameSource] [varchar] (100) COLLATE Latin1_General_CI_AS NOT NULL,
[entityTypeNameDest] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[hashDest] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[fieldNameDest] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[Navigation] ADD CONSTRAINT [PK_Navigation] PRIMARY KEY CLUSTERED ([NavigationKey], [entityTypeNameSource], [hashSource], [fieldNameSource]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[Navigation] ADD CONSTRAINT [FK_Navigation_entityType] FOREIGN KEY ([entityTypeNameSource], [hashSource]) REFERENCES [AwmConfig].[entityType] ([entityTypeName], [hash]) ON UPDATE CASCADE
GO
ALTER TABLE [AwmConfig].[Navigation] ADD CONSTRAINT [FK_Navigation_FieldsData] FOREIGN KEY ([entityTypeNameSource], [fieldNameSource]) REFERENCES [AwmConfig].[FieldsData] ([entityTypeName], [fieldName])
GO
