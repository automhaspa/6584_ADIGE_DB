CREATE TABLE [AwmConfig].[LocalResource]
(
[LanguageId] [nvarchar] (2) COLLATE Latin1_General_CI_AS NOT NULL,
[ResourceName] [nvarchar] (200) COLLATE Latin1_General_CI_AS NOT NULL,
[ResourceValue] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[LocalResource] ADD CONSTRAINT [PK_dbo.LocalResource] PRIMARY KEY CLUSTERED ([LanguageId], [ResourceName]) ON [PRIMARY]
GO
