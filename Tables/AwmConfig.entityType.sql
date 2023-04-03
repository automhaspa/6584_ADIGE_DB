CREATE TABLE [AwmConfig].[entityType]
(
[entityTypeName] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[hash] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[entityType] ADD CONSTRAINT [PK_entityType] PRIMARY KEY CLUSTERED ([entityTypeName], [hash]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[entityType] ADD CONSTRAINT [FK_entityType_Routes] FOREIGN KEY ([hash]) REFERENCES [AwmConfig].[Routes] ([hash]) ON DELETE CASCADE ON UPDATE CASCADE
GO
