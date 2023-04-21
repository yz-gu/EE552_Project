import matplotlib.pyplot as plt
import numpy as np

f = open("C:\\Softwares\\Vivado\\EE552_project\\EE552_Project.sim\\sim_1\\behav\\xsim\\time.txt")

list1 = []
numberlist = []
numberxlist = []

for line in f:
    value = int(line)
    if value < 1000:
        numberlist.append(value)

for item in numberlist:
    numberxlist.append(numberlist.index(item))

ypoints = np.array(numberlist)
counts = np.bincount(numberlist)
x = np.arange(counts.size)
mean_data = np.mean(ypoints)
fig, ax = plt.subplots() 
plt.plot(ypoints, c = 'SeaGreen')
plt.axhline(mean_data, color='r', linestyle='--', label='Mean')
plt.text(0.5, mean_data, f"Mean = {mean_data:.0f}", color='r')
plt.xticks(np.arange(0, len(ypoints), 40))
ax.set_xlabel("outputnumber")
ax.set_ylabel("cycles")
plt.show()


plt.bar(x, counts)
plt.yticks(np.arange(0, counts.max()+1, 2))
fig, ax = plt.subplots()  # create a figure and axes object
ax.bar(x, counts, width=0.8)  # set the width of the bars to 0.5

# Add count values on top of each column
for i, v in enumerate(counts):
    if(v>0):
        ax.text(i - 0.9, v + 0.2, str(v),fontsize=8)
ax.set_xlabel("cycles")
ax.set_ylabel("frequency")
plt.show()

# print(numberlist)