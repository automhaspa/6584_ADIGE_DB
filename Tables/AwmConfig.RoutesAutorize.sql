CREATE TABLE [AwmConfig].[RoutesAutorize]
(
[hash] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[autorize] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[ID] [int] NOT NULL IDENTITY(1, 1)
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[RoutesAutorize] ADD CONSTRAINT [PK_RoutesAutorize_1] PRIMARY KEY CLUSTERED ([hash], [autorize]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[RoutesAutorize] ADD CONSTRAINT [FK_RoutesAutorize_Autorize] FOREIGN KEY ([hash]) REFERENCES [AwmConfig].[Routes] ([hash]) ON DELETE CASCADE ON UPDATE CASCADE
GO
