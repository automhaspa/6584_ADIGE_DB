CREATE TABLE [PrintService].[PrintList]
(
[Print_Id] [int] NOT NULL IDENTITY(1, 1),
[Printer_Id] [int] NOT NULL,
[Template_Name] [varchar] (100) COLLATE Latin1_General_CI_AS NOT NULL,
[Data_Dictionary] [varchar] (max) COLLATE Latin1_General_CI_AS NOT NULL,
[Status] [int] NOT NULL CONSTRAINT [DF_PrintList_Status] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [PrintService].[PrintList] ADD CONSTRAINT [PK__PrintLis__7A32177E2F5AF11A] PRIMARY KEY CLUSTERED ([Print_Id]) ON [PRIMARY]
GO
