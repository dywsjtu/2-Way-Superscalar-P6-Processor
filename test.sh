#!/bin/bash
make nuke > /dev/null 2>&1
rm output/*

if [[ $1 == "test" ]]
then
    for file in test_progs/*.s; do
        make clean
        echo "Assemble $(basename $file)"
        type=$(echo $file | cut -d'.' -f2)
        export SOURCE=$file
        # if [ $type = "s" ]; then
        #     make assembly > /dev/null 2>&1
        # else
        #     make program > /dev/null 2>&1
        # fi
        make assembly 
        echo "Running $(basename $file)"
        make
        echo "Saving $(basename $file) output"
        # cp writeback.out ./example_output/$(basename $file)_writeback.out
        # cp program.out ./example_output/$(basename $file)_program.out
        mv writeback.out ./output/$(basename $file)_writeback.out
        cat program.out | grep "@@@" > ./output/$(basename $file)_program.out
        diff ./output/$(basename $file)_writeback.out ./gt_output/$(basename $file)_writeback.out > /dev/null
        status=$? # 0 -> no difference
        if [[ "$status" -eq "0" ]]; then
            echo -e "$0: Test $(basename $file) writeback out \033[32m PASSED \033[0m"
        else
            echo -e "$0: Test $(basename $file) writeback out \033[31m FAILED \033[0m"
            break
        fi

        diff ./output/$(basename $file)_program.out ./gt_output/$(basename $file)_program.out > /dev/null
        status=$? # 0 -> no difference
        if [[ "$status" -eq "0" ]]; then
            echo -e "$0: Test $(basename $file) program out \033[32m PASSED \033[0m"
        else
            echo -e "$0: Test $(basename $file) program out \033[31m FAILED \033[0m"
            break
        fi
    done
    for file in test_progs/*.c; do
        make clean
        echo "Assemble $(basename $file)"
        type=$(echo $file | cut -d'.' -f2)
        export SOURCE=$file
        # if [ $type = "s" ]; then
        #     make assembly > /dev/null 2>&1
        # else
        #     make program > /dev/null 2>&1
        # fi
        make program
        echo "Running $(basename $file)"
        make 
        echo "Saving $(basename $file) output"
        # cp writeback.out ./example_output/$(basename $file)_writeback.out
        # cp program.out ./example_output/$(basename $file)_program.out
        mv writeback.out ./output/$(basename $file)_writeback.out
        cat program.out | grep "@@@" > ./output/$(basename $file)_program.out
        diff ./output/$(basename $file)_writeback.out ./gt_output/$(basename $file)_writeback.out > /dev/null
        status=$? # 0 -> no difference
        if [[ "$status" -eq "0" ]]; then
            echo -e "$0: Test $(basename $file) writeback out \033[32m PASSED \033[0m"
        else
            echo -e "$0: Test $(basename $file) writeback out \033[31m FAILED \033[0m"
            break
        fi

        diff ./output/$(basename $file)_program.out ./gt_output/$(basename $file)_program.out > /dev/null
        status=$? # 0 -> no difference
        if [[ "$status" -eq "0" ]]; then
            echo -e "$0: Test $(basename $file) program out \033[32m PASSED \033[0m"
        else
            echo -e "$0: Test $(basename $file) program out \033[31m FAILED \033[0m"
            break
        fi
    done
elif [[ $1 == "syn" ]]
then
    make clean
    for file in test_progs/*.s; do
        
        echo "Assemble $(basename $file)"
        type=$(echo $file | cut -d'.' -f2)
        export SOURCE=$file
        # if [ $type = "s" ]; then
        #     make assembly > /dev/null 2>&1
        # else
        #     make program > /dev/null 2>&1
        # fi
        make assembly
        echo "Running $(basename $file)"
        make syn
        echo "Saving $(basename $file) output"
        # cp writeback.out ./example_output/$(basename $file)_writeback.out
        # cp program.out ./example_output/$(basename $file)_program.out
        mv writeback.out ./output/$(basename $file)_writeback.out
        cat syn_program.out | grep "@@@" > ./output/$(basename $file)_program.out
        diff ./output/$(basename $file)_writeback.out ./gt_output/$(basename $file)_writeback.out > /dev/null
        status=$? # 0 -> no difference
        if [[ "$status" -eq "0" ]]; then
            echo -e "$0: Test $(basename $file) writeback out \033[32m PASSED \033[0m"
        else
            echo -e "$0: Test $(basename $file) writeback out \033[31m FAILED \033[0m"
            break
        fi

        diff ./output/$(basename $file)_program.out ./gt_output/$(basename $file)_program.out > /dev/null
        status=$? # 0 -> no difference
        if [[ "$status" -eq "0" ]]; then
            echo -e "$0: Test $(basename $file) program out \033[32m PASSED \033[0m"
        else
            echo -e "$0: Test $(basename $file) program out \033[31m FAILED \033[0m"
            break
        fi
    done
    for file in test_progs/*.c; do
        # make clean
        echo "Assemble $(basename $file)"
        type=$(echo $file | cut -d'.' -f2)
        exit
        export SOURCE=$file
        # if [ $type = "s" ]; then
        #     make assembly > /dev/null 2>&1
        # else
        #     make program > /dev/null 2>&1
        # fi
        make program
        echo "Running $(basename $file)"
        make syn
        echo "Saving $(basename $file) output"
        # cp writeback.out ./example_output/$(basename $file)_writeback.out
        # cp program.out ./example_output/$(basename $file)_program.out
        mv writeback.out ./output/$(basename $file)_writeback.out
        cat program.out | grep "@@@" > ./output/$(basename $file)_program.out
        diff ./output/$(basename $file)_writeback.out ./gt_output/$(basename $file)_writeback.out > /dev/null
        status=$? # 0 -> no difference
        if [[ "$status" -eq "0" ]]; then
            echo -e "$0: Test $(basename $file) writeback out \033[32m PASSED \033[0m"
        else
            echo -e "$0: Test $(basename $file) writeback out \033[31m FAILED \033[0m"
            break
        fi

        diff ./output/$(basename $file)_program.out ./gt_output/$(basename $file)_program.out > /dev/null
        status=$? # 0 -> no difference
        if [[ "$status" -eq "0" ]]; then
            echo -e "$0: Test $(basename $file) program out \033[32m PASSED \033[0m"
        else
            echo -e "$0: Test $(basename $file) program out \033[31m FAILED \033[0m"
            break
        fi
    done
else echo -e "\033[31m Wrong Args \033[0m"
fi

