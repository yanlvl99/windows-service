-- src/Enums.luau
local Enums = {
	ShowType = {
		Hide = 0, Normal = 1, Minimize = 6, Maximize = 3, Restore = 9, ShowNoActivate = 4
	},
	MessageBox = {
		Type = {
			Ok = 0, OkCancel = 1, AbortRetryIgnore = 2, YesNoCancel = 3,
			YesNo = 4, RetryCancel = 5
		},
		Button = {
			[1]="OK", [2]="Cancel", [3]="Abort", [4]="Retry", [5]="Ignore",
			[6]="Yes", [7]="No", [10]="TryAgain", [11]="Continue"
		},
		Icon = {
			IconError = 16, IconQuestion = 32, IconWarning = 48, IconInfo = 64
		},
		Flag = {
			TopMost = 0x40000, SetForeground = 0x10000
		}
	}
}
return Enums