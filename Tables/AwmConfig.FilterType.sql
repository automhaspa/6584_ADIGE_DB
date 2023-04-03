CREATE TABLE [AwmConfig].[FilterType]
(
[filterTypeName] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[FilterType] ADD CONSTRAINT [PK_FilterType_1] PRIMARY KEY CLUSTERED ([filterTypeName]) ON [PRIMARY]
GO
