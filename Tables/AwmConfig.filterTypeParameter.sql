CREATE TABLE [AwmConfig].[filterTypeParameter]
(
[filterTypeName] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[parameterName] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[parameterValue] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[filterTypeParameter] ADD CONSTRAINT [PK_filterTypeParameter] PRIMARY KEY CLUSTERED ([filterTypeName], [parameterName]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[filterTypeParameter] ADD CONSTRAINT [FK_filterTypeParameter_FilterType] FOREIGN KEY ([filterTypeName]) REFERENCES [AwmConfig].[FilterType] ([filterTypeName]) ON DELETE CASCADE ON UPDATE CASCADE
GO
