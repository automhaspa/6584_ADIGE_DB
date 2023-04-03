CREATE TABLE [Custom].[PackingLists]
(
[Id_Packing_List] [int] NOT NULL IDENTITY(1, 1),
[Id_Testata_Lista_Prelievo] [int] NULL,
[Nome_Packing_List] [varchar] (30) COLLATE Latin1_General_CI_AS NOT NULL,
[Data_Creazione] [date] NOT NULL CONSTRAINT [DF__PackingLi__Data___75435199] DEFAULT (getdate())
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[PackingLists] ADD CONSTRAINT [PK__PackingL__07A9DDA671A4C166] PRIMARY KEY CLUSTERED ([Id_Packing_List]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[PackingLists] ADD CONSTRAINT [FK__PackingLi__Id_Te__744F2D60] FOREIGN KEY ([Id_Testata_Lista_Prelievo]) REFERENCES [Custom].[TestataListePrelievo] ([ID])
GO
