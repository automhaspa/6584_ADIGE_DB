CREATE TABLE [Printer].[Printer_Association]
(
[Id_Printer] [int] NOT NULL,
[Id_Partizione] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [Printer].[Printer_Association] ADD CONSTRAINT [PK__Printer___8B1E845A22185A64] PRIMARY KEY CLUSTERED ([Id_Printer], [Id_Partizione]) ON [PRIMARY]
GO
ALTER TABLE [Printer].[Printer_Association] ADD CONSTRAINT [FK_PrinterAssociation_1] FOREIGN KEY ([Id_Printer]) REFERENCES [Printer].[Printer] ([Id_Printer])
GO
ALTER TABLE [Printer].[Printer_Association] ADD CONSTRAINT [FK_PrinterAssociation_2] FOREIGN KEY ([Id_Partizione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
