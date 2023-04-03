CREATE TABLE [AwmConfig].[RoutesCustom]
(
[hash] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Pc] [int] NOT NULL,
[Id] [int] NOT NULL IDENTITY(1, 1)
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[RoutesCustom] ADD CONSTRAINT [PK_RoutesCustom] PRIMARY KEY CLUSTERED ([hash], [Id_Pc]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[RoutesCustom] ADD CONSTRAINT [FK_RoutesCustom_Pc] FOREIGN KEY ([Id_Pc]) REFERENCES [dbo].[Pc] ([Id_Pc])
GO
ALTER TABLE [AwmConfig].[RoutesCustom] ADD CONSTRAINT [FK_RoutesCustom_Routes] FOREIGN KEY ([hash]) REFERENCES [AwmConfig].[Routes] ([hash]) ON UPDATE CASCADE
GO
